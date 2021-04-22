#!/usr/bin/env ash

source /setup-kubeconfig.sh

exec /usr/bin/helm "$@"
