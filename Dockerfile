FROM alpine/helm:3.6.3

ARG HELMFILE_VERSION=0.141.0
ARG HELM_DIFF_VERSION=v3.1.3
ARG HELM_SECRETS_VERSION=v3.9.1
ARG HELM_S3_VERSION=v0.10.0
ARG HELM_GIT_VERSION=v0.11.1
ARG HELM_QUAY_VERSION=5e3f456fa6ab91e7a0d1a9c0880f562a6d6f9165
ARG HELM_QUAY_APPR_VERSION=v0.7.4
ARG YQ_VERSION=v4.14.1
ARG KUBECTL_VERSION=v1.19.15
# latest stable kubectl version can be found at: curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt

RUN apk add --update --no-cache git bash jq gettext curl && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq

# Install Helmfile
RUN curl -L -o helmfile_linux_amd64 https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 && \
    mv helmfile_linux_amd64 /usr/bin/helmfile && \
    chmod +x /usr/bin/helmfile && \
    rm -rf helmfile_linux_amd64

# Install quay plugin from github
RUN eval $(helm env | grep HELM_PLUGINS) && \
    git clone https://github.com/app-registry/quay-helmv3-plugin $HELM_PLUGINS/quay-helmv3-plugin && \
    cd $HELM_PLUGINS/quay-helmv3-plugin && \
    git checkout ${HELM_QUAY_VERSION} && \
    rm -r .git && \
    helm quay upgrade-plugin ${HELM_QUAY_APPR_VERSION}

# Install Helm pugins
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION}
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version ${HELM_SECRETS_VERSION}
RUN helm plugin install https://github.com/hypnoglow/helm-s3.git
# RUN helm plugin install https://github.com/hypnoglow/helm-s3.git --version 0.10.0
# RUN helm plugin install https://github.com/hypnoglow/helm-s3.git --version ${HELM_S3_VERSION}
RUN helm plugin install https://github.com/aslafy-z/helm-git.git --version ${HELM_GIT_VERSION}

COPY setup-kubeconfig.sh /
COPY run-helm.sh /

RUN chmod +x /run-helm.sh && \
    chmod +x /setup-kubeconfig.sh

ENTRYPOINT ["/run-helm.sh"]

CMD ["--help"]
