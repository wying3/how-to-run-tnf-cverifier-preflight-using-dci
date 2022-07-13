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

## Prepare and Deploy DCI Container using helm chart
- **Update helm chart values.yaml**
```yaml
global:
  imagePullSecrets:
    enabled: false
    name: art-regcred
  nodeselector:
    enabled: false
    key: dci
    value: container

  repository: quay.io/avu0
  imagecredential:
    registry: quay.io
    username: avu0
    password: vkc8O9xxmM435IeqhkBb

image:
  dcipreflight:
    imgname: dci-container-tpc
    tag: v1
    pullPolicy: IfNotPresent

nameOverride: ""
fullnameOverride: ""

hook_delete_policy: "hook-failed"
serviceAccount:
  name: "dci-container-sa"

dcinetipvlan:
  name: ipvlan
  hostDevice: eno6
  type: static
  cidr: 192.168.30.0/27
  allocationPoolStartIp: 192.168.30.20
  allocationPoolEndIp: 192.168.30.20
  routes:
  - dst: 172.168.20.0/24
    gw: 192.168.30.1

securityContext:
  privileged: true
  capabilities:
    add: ["NET_ADMIN","NET_RAW","SYS_ADMIN"]        

resources:
  limits:
    cpu: 4
    memory: 8Gi
  requests:
    cpu: 2
    memory: 4Gi
```
**Note:** serviceAccount name and namespace must be used on step when add SCC privileged 

- **Create Namespace and add SCC to SA user as priviledge**
```diff
+ oc create namespace dci
+ oc add-scc-to-user privileged system:serviceaccount:dci:dci-container-sa
```
- **Label the SNO or master/worker nodes if nodeSelector is used tell kubernetes to allocate this dci-container POD to specific node**
```diff
+ oc get no -o NAME | cut -d/ -f2|xargs -I V oc label node V dci=container
```
- **Deploy DCI Container using helmchart**
```diff
+ helm install dci-container dci-container/ -n dci --wait
+ helm ls -n dci
NAME             NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
dci-container      dci              1            2022-07-07 10:28:53.014745629 -0500 CDT deployed        dci-container-0.1.0                
+ oc get po -n dci
NAME                                       READY   STATUS    RESTARTS   AGE
dci-container-5fdf7f7fc4-9gzwc   1/1     Running   0          6d4h
```
