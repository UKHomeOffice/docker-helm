FROM alpine:3.18
ARG USER=helm
ARG UID=1000

ARG HELM_VERSION

ARG HELMFILE_VERSION=0.154.0
ARG HELMFILE_SHA512=8efe4b5fded09df7989a625a10856696a2260d7186037eeac39460b5fa248db975357648dad7b122401d095dfbb78f73bd2ed7d5e4f0c2f42af335ea0ae41486

ARG KUBECTL_VERSION=1.21.14
ARG KUBECTL_SHA512=4eda22a29a1f24acfc0a664024224ebffa0c51a545342b64ef438922f97afe2cccb8f48bedc85d5362af6694cbd4d6708f4ab55a6db570d11c24aa5942128d19

ARG YQ_VERSION=4.34.2
ARG YQ_SHA512=c35c34ddc175a1e5c2e37917834e3b099791845f5a7f765335d279aad86df9b1080904ed5260d860bd94467f1d0ba6bf935d8447dd96bd54370374d43f96a5d6

# HELM PLUGIN Versions
ARG HELM_PLUGIN_DIFF_VERSION=3.8.1
ARG HELM_PLUGIN_GIT_VERSION=0.15.1
ARG HELM_PLUGIN_S3_VERSION=0.14.0
ARG HELM_PLUGIN_SECRET_VERSION=3.15.0

COPY ./build_files/ /

RUN set -euxo pipefail ;\
  # Create non-Root user
  adduser \
  -D \
  -g "" \
  -u "$UID" \
  "$USER"  ;\
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
