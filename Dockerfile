# syntax=docker/dockerfile:1
#
# ACP helm image.
#
# Tool versions here are deliberately identical to what this image shipped
# before -- helm, kubectl, helmfile, yq and every plugin. Nothing is upgraded.
# The only version that moves is the Alpine base, because 3.20 is EOL and
# receives no security updates at all, which no amount of rebuilding fixes.
#
# Every Go binary here is compiled from upstream source with a current Go
# toolchain rather than installed from a release download. The versions shipped
# are unchanged -- this is purely about what they are built with. Nearly all the
# CVEs this image used to carry were Go stdlib and stale-dependency issues
# inherited from the toolchains the official binaries were released with, and
# kubectl 1.21.14 (built upstream with Go 1.16) was the single worst offender.
#
# See README.md for the measured before/after.

ARG ALPINE_VERSION=3.24
ARG GO_IMAGE=golang:1.26.7-alpine

# ---------------------------------------------------------------------------
# Build stage
# ---------------------------------------------------------------------------
FROM ${GO_IMAGE} AS build

# HELM_VERSION is supplied by the pipeline from .semver (e.g. 3.19.0).
ARG HELM_VERSION

# kubectl is pinned to 1.21.14 to match the ACP clusters. Do not raise it.
# KUBECTL_COMMIT is the commit v1.21.14 points at; it is verified after
# checkout so a re-pointed tag fails the build instead of silently changing
# what we ship, and it is stamped into the binary as the git commit.
ARG KUBECTL_VERSION=1.21.14
ARG KUBECTL_COMMIT=0f77da5bd4809927e15d1658fb4aa8f13ad890a5

# Security-only dependency bumps applied to every Go project built here. These
# are the libraries that actually accumulate CVEs between releases; the tools'
# own versions are untouched. x/oauth2 and docker/docker are deliberately
# absent by design, all tried and reverted: x/oauth2 drags in a conflicting
# cloud.google.com/go; docker/docker@latest (v28) leaves helm 3.19 with an
# unresolvable go.sum for github.com/fatih/color. `go mod tidy` rescues
# neither. Trim this list as upstreams catch up rather than letting it rot.
ARG GO_SECURITY_BUMPS="golang.org/x/crypto golang.org/x/net golang.org/x/text golang.org/x/sys oras.land/oras-go/v2 github.com/containerd/containerd google.golang.org/grpc"

# helmfile gets its own list, without grpc. helmfile 0.171.0 cannot take any
# grpc bump: its graph hits "ambiguous import" between grpc's own
# stats/opentelemetry and the standalone module of the same path. That leaves
# one CRITICAL (CVE-2026-33186) which only a move to helmfile v1.x can fix --
# a breaking upgrade for anyone's helmfile.yaml, so it is not done here.
ARG GO_SECURITY_BUMPS_HELMFILE="golang.org/x/crypto golang.org/x/net golang.org/x/text golang.org/x/sys oras.land/oras-go/v2 github.com/containerd/containerd"

ARG HELMFILE_VERSION=0.171.0
ARG YQ_VERSION=4.48.1
ARG HELM_PLUGIN_DIFF_VERSION=3.13.0
ARG HELM_PLUGIN_S3_VERSION=0.17.0

# Declared WITHOUT a default on purpose. Buildkit only auto-populates this when
# it is undefaulted -- give it one and the default silently wins, which on an
# arm64 workstation yields an arm64 base holding amd64 binaries. The :-amd64
# fallback at each use site covers the classic builder, which never sets it.
ARG TARGETARCH

RUN apk add --no-cache git

ENV CGO_ENABLED=0 \
    GOOS=linux

WORKDIR /build

# --- kubectl ---------------------------------------------------------------
# k8s 1.21 predates the module tooling in current Go by ten releases, so this
# needs three deviations from a plain `go build`:
#   -mod=mod        1.21's vendor/ tree is rejected outright by Go 1.26
#   -dropreplace    k8s pins every dependency with a `replace` directive, which
#                   silently overrides `go get`. Without dropping these first,
#                   the bumps below appear to apply but the binary still links
#                   the 2021 versions.
#   -X ...version   k8s stamps its version via ldflags. Omit them and the
#                   binary reports v0.0.0-master, which the entrypoint prints
#                   and anything version-gating would misread.
# x/oauth2 is deliberately NOT bumped: it pulls a cloud.google.com/go that
# collides with the pinned one ("ambiguous import"). Costs one LOW finding.
RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${KUBECTL_VERSION}" \
      https://github.com/kubernetes/kubernetes.git src-kubectl ;\
    cd src-kubectl ;\
    actual="$(git rev-parse HEAD)" ;\
    [ "$actual" = "${KUBECTL_COMMIT}" ] || { echo "kubectl commit mismatch: $actual" >&2; exit 1; } ;\
    go mod edit -go=1.23 ;\
    for d in golang.org/x/crypto golang.org/x/net golang.org/x/text golang.org/x/sys \
             google.golang.org/protobuf gopkg.in/yaml.v3 github.com/moby/spdystream ; do \
      go mod edit -dropreplace="$d" ; go get "$d@latest" ; \
    done ;\
    LD="-s -w" ;\
    for p in k8s.io/component-base/version k8s.io/client-go/pkg/version ; do \
      LD="$LD -X $p.gitVersion=v${KUBECTL_VERSION} -X $p.gitCommit=${KUBECTL_COMMIT}" ;\
      LD="$LD -X $p.gitTreeState=clean -X $p.gitMajor=1 -X $p.gitMinor=21" ;\
      LD="$LD -X $p.buildDate=1970-01-01T00:00:00Z" ; \
    done ;\
    GOARCH="${TARGETARCH:-amd64}" go build -mod=mod -trimpath -ldflags "$LD" -o /out/kubectl ./cmd/kubectl ;\
    cd / && rm -rf /build/src-kubectl

# --- helm ------------------------------------------------------------------
RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${HELM_VERSION}" \
      https://github.com/helm/helm.git src-helm ;\
    cd src-helm ;\
    commit="$(git rev-parse HEAD)" ;\
    for d in ${GO_SECURITY_BUMPS} ; do go get "$d@latest" || true ; done ;\
    V=helm.sh/helm/v3/internal/version ;\
    GOARCH="${TARGETARCH:-amd64}" go build -trimpath \
      -ldflags "-s -w -X $V.version=v${HELM_VERSION} -X $V.gitCommit=$commit -X $V.gitTreeState=clean" \
      -o /out/helm ./cmd/helm ;\
    cd / && rm -rf /build/src-helm

# --- helmfile --------------------------------------------------------------
RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${HELMFILE_VERSION}" \
      https://github.com/helmfile/helmfile.git src-helmfile ;\
    cd src-helmfile ;\
    for d in ${GO_SECURITY_BUMPS_HELMFILE} ; do go get "$d@latest" || true ; done ;\
    GOARCH="${TARGETARCH:-amd64}" go build -trimpath \
      -ldflags "-s -w -X go.szostok.io/version.version=v${HELMFILE_VERSION}" \
      -o /out/helmfile . ;\
    cd / && rm -rf /build/src-helmfile

# --- yq --------------------------------------------------------------------
RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${YQ_VERSION}" \
      https://github.com/mikefarah/yq.git src-yq ;\
    cd src-yq ;\
    for d in ${GO_SECURITY_BUMPS} ; do go get "$d@latest" || true ; done ;\
    GOARCH="${TARGETARCH:-amd64}" go build -trimpath -ldflags "-s -w" -o /out/yq . ;\
    cd / && rm -rf /build/src-yq

# --- helm plugins with Go binaries ----------------------------------------
# Built from source and laid out by hand rather than via `helm plugin install`,
# whose install hooks download prebuilt release binaries -- exactly the thing
# this image is trying to stop shipping.
RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${HELM_PLUGIN_DIFF_VERSION}" \
      https://github.com/databus23/helm-diff.git src-diff ;\
    cd src-diff ;\
    for d in ${GO_SECURITY_BUMPS} ; do go get "$d@latest" || true ; done ;\
    mkdir -p /out/plugins/helm-diff/bin ;\
    cp plugin.yaml /out/plugins/helm-diff/ ;\
    GOARCH="${TARGETARCH:-amd64}" go build -trimpath -ldflags "-s -w" -o /out/plugins/helm-diff/bin/diff . ;\
    cd / && rm -rf /build/src-diff

RUN set -eux ;\
    git clone --quiet --depth 1 --branch "v${HELM_PLUGIN_S3_VERSION}" \
      https://github.com/hypnoglow/helm-s3.git src-s3 ;\
    cd src-s3 ;\
    for d in ${GO_SECURITY_BUMPS} ; do go get "$d@latest" || true ; done ;\
    mkdir -p /out/plugins/helm-s3/bin ;\
    cp plugin.yaml /out/plugins/helm-s3/ ;\
    GOARCH="${TARGETARCH:-amd64}" go build -trimpath -ldflags "-s -w" \
      -o /out/plugins/helm-s3/bin/helm-s3 ./cmd/helm-s3 ;\
    cd / && rm -rf /build/src-s3

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}

ARG USER=helm
ARG UID=1000

# Shell-only plugins: no compiled binary, so nothing to rebuild. Cloned at a
# pinned tag rather than `helm plugin install`ed so the build does not execute
# an upstream install hook.
ARG HELM_PLUGIN_GIT_VERSION=0.17.0
ARG HELM_PLUGIN_SECRET_VERSION=4.6.11

COPY ./build_files/ /
COPY --from=build /out/kubectl  /usr/local/bin/kubectl
COPY --from=build /out/helm     /usr/local/bin/helm
COPY --from=build /out/helmfile /usr/local/bin/helmfile
COPY --from=build /out/yq       /usr/local/bin/yq
COPY --from=build /out/plugins/ /root/.local/share/helm/plugins/

RUN set -eux ;\
    adduser -D -g "" -u "$UID" "$USER" ;\
    apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      curl \
      gettext \
      git \
      jq \
      openssl ;\
    chmod +x /usr/local/bin/kubectl /usr/local/bin/helm \
             /usr/local/bin/helmfile /usr/local/bin/yq \
             /root/.local/share/helm/plugins/*/bin/* ;\
    # ACP CAs. Note these go straight to /usr/local/share/ca-certificates,
    # which is where update-ca-certificates actually reads from. The previous
    # Dockerfile staged them in /tmp/installroot/usr/local/share/ca-certificates
    # and nothing ever copied that into place, so the certs were downloaded,
    # left in /tmp and never trusted -- verified by fingerprint against the
    # published 3.19.0-build.1 image, where the ACP root is absent from
    # /etc/ssl/certs/ca-certificates.crt.
    mkdir -p /usr/local/share/ca-certificates ;\
    git clone --quiet --depth 1 https://github.com/UKHomeOffice/acp-ca.git /tmp/acp-ca ;\
    mv /tmp/acp-ca/ca.pem /usr/local/share/ca-certificates/acp_root_ca.crt ;\
    mv /tmp/acp-ca/ca-intermediate.pem /usr/local/share/ca-certificates/acp_int_ca.crt ;\
    rm -rf /tmp/acp-ca ;\
    # Shell-only helm plugins
    p=/root/.local/share/helm/plugins ;\
    git clone --quiet --depth 1 --branch "v${HELM_PLUGIN_GIT_VERSION}" \
      https://github.com/aslafy-z/helm-git.git "$p/helm-git" ;\
    git clone --quiet --depth 1 --branch "v${HELM_PLUGIN_SECRET_VERSION}" \
      https://github.com/jkroepke/helm-secrets.git "$p/helm-secrets" ;\
    git clone --quiet --depth 1 \
      https://github.com/app-registry/quay-helmv3-plugin.git "$p/quay" ;\
    find "$p" -name .git -type d -prune -exec rm -rf {} + ;\
    chown -R $USER:$USER /usr/local/share/ca-certificates /etc/ssl/certs/ ;\
    update-ca-certificates ;\
    chmod +x /entrypoint.sh ;\
    helm version ;\
    kubectl version --client ;\
    helm plugin list

# Root might be required by drone.io pipelines
#USER $UID

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
