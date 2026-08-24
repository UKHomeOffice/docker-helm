# docker-helm

Docker image for client-side only Helm (v3+).

Includes support for declarative Helm deployments with Helmfile, helm-diff, helm-secrets, helm-git and helm-s3 plugins.

This image sets up a kube config file that is then used by helm.


The kube config file is populated from environment variables.

Variable | Comment | Required 
---|---|---
KUBE_SERVER | The URL of the Kube API server to which the Helm packages should be deployed | required 
KUBE_TOKEN | The Kube access token | required
KUBE_CLUSTER_NAME | The kubernetes cluster name | required
KUBE_CERTIFICATE_AUTHORITY | The URL for the kube CA certificate file | optional
KUBE_CERTIFICATE_AUTHORITY_DATA | The base64 encoded kube CA certificate file | optional

If neither `KUBE_CERTIFICATE_AUTHORITY` or `KUBE_CERTIFICATE_AUTHORITY_DATA` are defined, the certificate is obtained from  Github and the `KUBE_CLUSTER_NAME` is assumed to be the name of an ACP cluster.

If `KUBE_CERTIFICATE_AUTHORITY` is defined but `KUBE_CERTIFICATE_AUTHORITY_DATA` is not, then `KUBE_CERTIFICATE_AUTHORITY` is assumed to be a URL and the certificate is downloaded from there.

Finally, if `KUBE_CERTIFICATE_AUTHORITY_DATA` is defined, it is assumed to contain the base64-encoded kube CA certificate.

The image runs `helm` and all parameters are passed to it.

This image is published on [quay.io](https://quay.io/repository/ukhomeofficedigital/helm)


## Versioning
The container image will be based on the HELM release version as outlined in https://github.com/helm/helm/releases

However, due to automated ACP build processes and other dependencies such as kubectl the tag following tag format will be used:
`<Drone Version>-build.x` where x is an incrementing integer

Upon satisfactory testing, the build version will be promoted to the helm version tag in quay.io.

Versioning will be maintained by updating the `.semver` file. E.g. should HELM 3.99.999 release, the `.semver` file will need to be `3.99.999-build.0`

## Security posture

All Go binaries in this image (`helm`, `kubectl`, `helmfile`, `yq`, and the
`helm-diff` / `helm-s3` plugin binaries) are **compiled from upstream source
with a current Go toolchain** rather than installed from release downloads.
**No tool versions change** — helm, kubectl, helmfile, yq and every plugin are
exactly what this image shipped before. This is only about what they are built
with. The sole exception is the Alpine base, which had to move off the now-EOL
3.20; nothing else is upgraded, so there is no behaviour change for consumers.

The reason is that almost every CVE this image carried came from the toolchain
and dependency set the official binaries happened to be released with, not from
the tools themselves. `kubectl` 1.21.14 was the worst case: upstream built it
with Go 1.16, which alone accounted for a ~50-entry block in `.trivyignore`.

Measured with Trivy, all severities, against `quay.io/ukhomeofficedigital/helm:3.19.0-build.1`:

| | before | after |
|---|---|---|
| CRITICAL | 16 | 1 |
| HIGH | 294 | 23 |
| MEDIUM | 259 | 27 |
| LOW | 47 | 8 |
| **total** | **625** | **64** |

Alpine OS packages went from 68 findings to 0, mostly by moving off the
now-EOL Alpine 3.20.

Two mechanisms do the work, both in the Dockerfile:

- **A current Go toolchain.** Pinned via `GO_IMAGE`. Worth bumping to the
  latest patch when Go releases one — stdlib CVEs land in *every* binary at
  once, so a single patch bump removed 48 findings here.
- **`GO_SECURITY_BUMPS`.** A short list of libraries that reliably accumulate
  CVEs between releases (`x/crypto`, `x/net`, `grpc`, `containerd`, …), bumped
  in each project before building. Deliberate exclusions are documented inline
  where they sit — each was tried and reverted because it broke a build.

`kubectl` needs three extra deviations from a plain `go build`, all commented
in the Dockerfile: `-mod=mod` (Go 1.26 rejects k8s 1.21's `vendor/` tree),
`go mod edit -dropreplace` (k8s pins every dependency with `replace`, which
silently overrides `go get`), and version `-ldflags` (without them the binary
reports `v0.0.0-master`, which the entrypoint prints).

`.trivyignore` lists only what genuinely cannot be fixed behind the version
pins, with a reason per group. It should stay short — if it starts growing
again, that is a signal something needs rebuilding rather than suppressing.

### ACP CA trust

The ACP root and intermediate CAs are installed into
`/usr/local/share/ca-certificates` and picked up by `update-ca-certificates`.

This is a fix, not a refactor. The previous Dockerfile staged them under
`/tmp/installroot/usr/local/share/ca-certificates`, which nothing ever copied
into place — so they were fetched, stranded in `/tmp`, and never entered the
trust store. Confirmed by fingerprint: the ACP root CA is **absent** from
`/etc/ssl/certs/ca-certificates.crt` in the published `3.19.0-build.1` image
and **present** here. Anything talking to an ACP-issued TLS endpoint was
failing certificate validation before.

### Version compatibility

The ACP clusters run Kubernetes **1.21.14**, which is outside helm's supported
skew (helm 3.19 targets client-go v0.34, and helm supports n-3 minors). This
was tested directly against a live 1.21.14 cluster: `helm list`,
`helm template --validate`, capability detection and `install --dry-run=server`
all behave correctly, because helm reads `.Capabilities` from the live API
server rather than from the binary's own client-go version. Charts gate on the
cluster, not on the helm version.

`kubectl` is pinned to **1.21.14** to match the clusters and should not be
raised.
