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

Upon satisfactory testing, the build version will be promoted to both the helm version tag and latest in quay.io

Versioning will be maintained by updating the `.semver` file. E.g. should HELM 3.99.999 release, the `.semver` file will need to be `3.99.999-build.0`