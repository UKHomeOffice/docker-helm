# docker-helm

Docker image for client-side only Helm (v3+).

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