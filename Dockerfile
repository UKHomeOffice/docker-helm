FROM alpine/helm:3.0.1

RUN apk add --update --no-cache gettext curl && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

COPY run-helm.sh /

RUN chmod +x /run-helm.sh

ENTRYPOINT ["/run-helm.sh"]

CMD ["--help"]