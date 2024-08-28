# OSS Integration Chart

## Overview

OSS Integration Chart provides the ability to co-deploy SO, UDS and PF.

## Installation Procedure

```
helm install --wait --timeout 1200
    --name <RELEASE_NAME>  <ERIC_OSS_HELM_CHART>
    --namespace <NAMESPACE>
    --set eric-sec-access-mgmt.ingress.hostname=<IAM_HOSTNAME>
    --set eric-eo-usermgmt.iam.admin.url="https://<IAM_HOSTNAME>/auth/realms/master"
    --set global.hosts.iam=<IAM_HOSTNAME>
    --set tags.so=true,tags.pf=true,tags.uds=true,platform=true # OPTIONAL
```

### Logging

  Logging is installed by default, but can be disabled when required:
  * logging.enabled=<true|false> default value is true

### PM Server

  The PM Server is installed by default, but can be disabled when required:
  * eric-pm-server.enabled=<true|false> default value is true

