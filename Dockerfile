FROM alpine/helm:3.2.1

ARG HELMFILE_VERSION=0.116.0
ARG HELM_DIFF_VERSION=3.1.1
ARG HELM_SECRETS_VERSION=2.0.2
ARG HELM_S3_VERSION=0.9.2
ARG HELM_GIT_VERSION=0.7.0


RUN apk add --update --no-cache git bash jq gettext curl && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Install Helmfile
RUN curl -L -o helmfile_linux_amd64 https://github.com/roboll/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_linux_amd64 && \
    mv helmfile_linux_amd64 /usr/bin/helmfile && \
    chmod +x /usr/bin/helmfile && \
    rm -rf helmfile_linux_amd64

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
