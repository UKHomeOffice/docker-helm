FROM alpine:3.20
ARG USER=helm
ARG UID=1000

ARG HELM_VERSION

ARG HELMFILE_VERSION=0.171.0
ARG HELMFILE_SHA512=115489765a728f806db3390cca6185d5201776da1c91f081b9e2f43a1ef300a280478084d1d27150553b743570f424c8f2bf338193b9ec6c5c56b99d09e20645

ARG KUBECTL_VERSION=1.21.14
ARG KUBECTL_SHA512=4eda22a29a1f24acfc0a664024224ebffa0c51a545342b64ef438922f97afe2cccb8f48bedc85d5362af6694cbd4d6708f4ab55a6db570d11c24aa5942128d19

ARG YQ_VERSION=4.48.1
ARG YQ_SHA512=b5a12b66b176b16deb2e252f3c8e9568165daa0c449486134ec6dc6783b97fb492b57126a2f581f6275ee386e3457a2af1cd2785a9ca4f0a442e11316853176a

# HELM PLUGIN Versions
ARG HELM_PLUGIN_DIFF_VERSION=3.13.0
ARG HELM_PLUGIN_GIT_VERSION=0.17.0
ARG HELM_PLUGIN_S3_VERSION=0.17.0
ARG HELM_PLUGIN_SECRET_VERSION=4.6.11

COPY ./build_files/ /

RUN set -euxo pipefail ;\
  # Create non-Root user
  adduser \
  -D \
  -g "" \
  -u "$UID" \
  "$USER"  ;\
  # Update packages
  apk update && apk upgrade;\
  #Install Dependencies
  apk add --no-cache \
    bash \
    curl \
    coreutils \
    gettext \
    git \
    jq \
    openssl ;\
  #Create directories to hold files intended for final container e.g. package dependencies
  mkdir -p /tmp/installroot/usr/local/share/ca-certificates ;\
  #Retreive ACP CAs
  git clone https://github.com/UKHomeOffice/acp-ca.git /tmp/acp-ca ;\
  mv /tmp/acp-ca/ca.pem /tmp/installroot/usr/local/share/ca-certificates/acp_root_ca.crt ;\
  mv /tmp/acp-ca/ca-intermediate.pem /tmp/installroot/usr/local/share/ca-certificates/acp_int_ca.crt ;\
  rm -rf /tmp/acp-ca ;\
  # Install YQ
  curl -sLo /tmp/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" ;\
  echo "$YQ_SHA512 /tmp/yq" | sha512sum --strict --check - ;\
  mv /tmp/yq /usr/local/bin/ ;\
  chmod +x /usr/local/bin/yq ;\
  # Install Kubectl
  curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" ;\
  echo "$KUBECTL_SHA512 ./kubectl" | sha512sum --strict --check - ;\
  mv ./kubectl /usr/local/bin/ ;\
  chmod +x /usr/local/bin/kubectl ;\
  # Install Helm 3
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- -v v$HELM_VERSION ;\
  chmod +x /usr/local/bin/helm ;\
  rm -f /tmp/helm.tar.gz* ;\
  rm -rf /tmp/helm ;\
  # Install HELM File
  curl -sLo /tmp/helmfile.tar.gz https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz ;\
  echo "$HELMFILE_SHA512 /tmp/helmfile.tar.gz" | sha512sum --strict --check - ;\
  mkdir -p /tmp/helmfile ;\
  tar -C /tmp/helmfile -zxvf /tmp/helmfile.tar.gz ;\
  mv /tmp/helmfile/helmfile /usr/local/bin/ ;\
  rm -f /tmp/helmfile.tar.gz* ;\
  rm -rf /tmp/helmfile ;\
  #change ownership of /usr/local/share/ca-certificates as alpine does not suppport directories.
  chown -R $USER:$USER /usr/local/share/ca-certificates ;\
  chown -R $USER:$USER /etc/ssl/certs/ ;\
  ls -lRt /usr/local/share/ca-certificates ;\
  update-ca-certificates ;\
  chmod +x /entrypoint.sh ;

# Root might be required by drone.io pipelines
#USER $UID

# Extra layer as helm plugins are installed to user home directories
RUN set -euxo pipefail ;\
  # Install HELM Plugins
  #Quay - no version to pin 
  helm plugin install https://github.com/app-registry/quay-helmv3-plugin ;\
  #Diff
  helm plugin install https://github.com/databus23/helm-diff --version v${HELM_PLUGIN_DIFF_VERSION} ;\
  #git
  helm plugin install https://github.com/aslafy-z/helm-git --version v${HELM_PLUGIN_GIT_VERSION} ;\
  #S3
  helm plugin install https://github.com/hypnoglow/helm-s3 --version v${HELM_PLUGIN_S3_VERSION} ;\
  #Secrets
  helm plugin install https://github.com/jkroepke/helm-secrets --version v${HELM_PLUGIN_SECRET_VERSION} ;\
  helm version ;\
  kubectl version --client ;

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
