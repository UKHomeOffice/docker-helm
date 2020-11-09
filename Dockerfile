FROM alpine/helm:3.4.0

ARG HELMFILE_VERSION=0.134.0
ARG HELM_DIFF_VERSION=3.1.3
ARG HELM_SECRETS_VERSION=2.0.2
ARG HELM_S3_VERSION=0.10.0
ARG HELM_GIT_VERSION=0.8.1
ARG HELM_QUAY_VERSION=5e3f456fa6ab91e7a0d1a9c0880f562a6d6f9165
ARG HELM_QUAY_APPR_VERSION=v0.7.4
ARG YQ_VERSION=3.4.1


RUN apk add --update --no-cache git bash jq gettext curl && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
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
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION} && \
    helm plugin install https://github.com/futuresimple/helm-secrets --version ${HELM_SECRETS_VERSION} && \
    helm plugin install https://github.com/hypnoglow/helm-s3.git --version ${HELM_S3_VERSION} && \
    helm plugin install https://github.com/aslafy-z/helm-git.git --version ${HELM_GIT_VERSION}

COPY setup-kubeconfig.sh /
COPY run-helm.sh /

RUN chmod +x /run-helm.sh && \
    chmod +x /setup-kubeconfig.sh

ENTRYPOINT ["/run-helm.sh"]

CMD ["--help"]
