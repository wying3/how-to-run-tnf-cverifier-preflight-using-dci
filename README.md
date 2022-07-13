# how-to-run-tnf-cverifier-preflight-using-dci
This GIT repository is to show how to use DCI as centralize tool to run the following tests TNF Test Suite, Helm Chart-verifier and Preflight (Scan the image).

## Pre-requisites
- **One OAM subnet for secondary POD interface to reach https://www.distributed-ci.io for submission**
- **An Openshift cluster either SNO or Compact/Hub Cluster**
- **An account that can access to ci.io with DCI client-id and secrets https://www.distributed-ci.io/remotecis**
## Build DCI container image with dci's requirements and preflight binary inside the image
```diff
+ oc git clone https://github.com/redhat-openshift-ecosystem/openshift-preflight.git
+ podman build -t dci-container-tpc:v1 -f ./Dockerfile-WithPreflight
+ podman tag dci-container-tpc:v1 quay.io/avu0/dci-container-tpc:v1
+ podman push quay.io/avu0/dci-container-tpc:v1
```

## Build DCI container image with dci's requirements only
```diff
+ podman build -t dci-container-tpc:v1 -f ./Dockerfile
+ podman tag dci-container-tpc:v1 quay.io/avu0/dci-container-tpc:v1
+ podman push quay.io/avu0/dci-container-tpc:v1
```

