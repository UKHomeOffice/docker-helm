#!/usr/bin/env bash

set -eo pipefail

#Print HELM and Kubectl Versions:
echo 'helm version::'
helm version
echo 'kubectl version::'
kubectl version --client

#Check Env Vars are set
if [ -z "${KUBE_SERVER}" ]; then
  echo "environment variable KUBE_SERVER should be defined as the Kubernetes API server's URL"
  exit 1
fi

if [ -z "${KUBE_TOKEN}" ]; then
  echo 'environment variable KUBE_TOKEN should be defined'
  exit 1
fi

if [ -z "${KUBE_CLUSTER_NAME}" ]; then
  echo 'environment variable KUBE_CLUSTER_NAME should be defined'
  exit 1
fi

if [ -z "${KUBE_CERTIFICATE_AUTHORITY_DATA}" ]; then
  # let's try to get the kube CA data since it is not set
  if [ -z "${KUBE_CERTIFICATE_AUTHORITY}" ]; then
    # let's try to get the kube CA data since it is not set
    KUBE_CERTIFICATE_AUTHORITY="https://raw.githubusercontent.com/UKHomeOffice/acp-ca/master/${KUBE_CLUSTER_NAME}.crt"
  fi
  KUBE_CERTIFICATE_AUTHORITY_DATA=$(curl -s $KUBE_CERTIFICATE_AUTHORITY | base64 | tr -d \\n )
fi

#Kubectl set config
kubectl config set-cluster ${KUBE_CLUSTER_NAME} --server=${KUBE_SERVER}
kubectl config set clusters.${KUBE_CLUSTER_NAME}.certificate-authority-data ${KUBE_CERTIFICATE_AUTHORITY_DATA}
kubectl config set-credentials helm --token=${KUBE_TOKEN}
kubectl config set-context ${KUBE_CLUSTER_NAME} --cluster=${KUBE_CLUSTER_NAME} --user=helm
kubectl config use-context ${KUBE_CLUSTER_NAME}

#execute HELM command
exec helm "$@"