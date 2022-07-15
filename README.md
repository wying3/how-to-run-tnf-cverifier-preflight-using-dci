# how-to-run-tnf-chart-verifier-preflight-using-dci
This GIT repository is to show how to use DCI as centralize tool to run the following tests TNF Test Suite, Helm Chart-verifier and Preflight (Scan the image). Additional, this respository also show how to use DCI to test above 3 main catagories not just on traditional helper node or VM but also aim to do demostration how to use DCI to run these 3 tests inside Kubernetes Container, where you dont need to install DCI, preflight and helm chart requirements RPMs or libraries.
  
In matter of facts, it has an extra benefits, example user can also scale out additional POD in seconds to run DCI testing for different application on same or different clusters. Finally, this repository also add the original manual methods of how to run these 3 steps without using DCI tool for references/troubleshooting.

## Pre-requisites
- One OAM subnet for secondary POD interface to reach https://www.distributed-ci.io as using for results/logs submission
- An Openshift cluster either SNO or Compact/Hub Cluster
- An account that can access to ci.io with DCI client-id and secrets https://www.distributed-ci.io/remotecis
- An real CNF application or a test-app that need to label them specifically and update to settings.yml
- Helm Chart testing needs to have a helmchart repository with index release if enable-helm-chart-testing  
  [Example-of-helm-chart-release](https://github.com/ansvu/samplechart2/releases/tag/samplechart-0.1.3)  
  Or Check out this document I made [Instruction-how-add-helm-chart-to-github](https://docs.google.com/presentation/d/1UEppK33-JMfCO4UzxgeDkL1zZpvIejdwv6lIM3tx4JY/edit?usp=sharing)  
  Or this more harder way original we used [Using CR tooling](https://docs.google.com/document/d/1pBkS0Z1mbbDZpKIytbTfPCSrMFayqUYZ6p2ngCxFkrU/edit?usp=sharing)

## Build DCI container image with dci's requirements and preflight binary inside the image
```diff
+ git clone https://github.com/redhat-openshift-ecosystem/openshift-preflight.git
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
### Update helm chart values.yaml
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
  allocationPoolEndIp: 192.168.30.21
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
- **Helm Chart Values Modification Options**  
   * ServiceAccount name and namespace must be used same name on step when add SCC privileged.
   * Adjust resources limits/requests of CPU and Memory according to your application SIZE
   * NodeSelector that allow kubernetes to deploy DCI container on specific node true/false
   * ImagePullSecret is enabled when you have a private registry server that need to autheticate.

### Create Namespace and add SCC to SA user as priviledge
```diff
+ oc create namespace dci
+ oc add-scc-to-user privileged system:serviceaccount:dci:dci-container-sa
```
### Label the SNO or master/worker nodes if nodeSelector is enabled to allocate this dci-container POD to specific node
```diff
+ oc get no -o NAME | cut -d/ -f2|xargs -I V oc label node V dci=container
```

### Deploy DCI Container using helmchart
```diff
+ tree dci-container/
dci-container/
├── Chart.yaml
├── templates
│   ├── createdci-pdb.yaml
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── ImagePullSecret.tpl
│   ├── ImageRepoPullSecret.yaml
│   ├── ipvlan.yaml
│   └── serviceaccount.yaml
└── values.yaml
- ---------------------------------------------------------------------------------------------------------------------------------
+ helm install dci dci-container/ -n dci --wait
+ helm ls -n dci
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
dci     dci             1               2022-07-13 15:26:29.697521572 -0500 CDT deployed        dci-container-0.1.0              
+ oc get po -n dci
NAME                                 READY   STATUS    RESTARTS   AGE
dci-dci-container-7b9669f68d-pxwf4   1/1     Running   0          3m55s
+ oc exec -it dci-dci-container-7b9669f68d-pxwf4 -- bash -n dci
[root@dci-dci-container-7b9669f68d-pxwf4 /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if16698: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:84:00:68 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.132.0.104/23 brd 10.132.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::858:aff:fe84:68/64 scope link 
       valid_lft forever preferred_lft forever
4: net1@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
    link/ether 94:40:c9:c1:eb:69 brd ff:ff:ff:ff:ff:ff
    inet 192.168.30.20/27 brd 192.168.30.31 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::9440:c900:6c1:eb69/64 scope link 
       valid_lft forever preferred_lft forever

[root@dci-dci-container-7b9669f68d-pxwf4 /]# ping 192.168.30.1 -c3
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=0.493 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.393 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=64 time=0.365 ms
```

### Scale out additional DCI Container for more users
  - if there are more users need to test for different CNF application  
    we can scale out additional DCI Container PODs if NAD has a range of more than one IP Addreses
```diff
+ oc scale Deployment/dci-dci-container --replicas=2 -n dci
deployment.apps/dci-dci-container scaled
+ oc get po -n dci
NAME                                 READY   STATUS    RESTARTS   AGE
dci-dci-container-7b9669f68d-pxwf4   1/1     Running   0          42h
dci-dci-container-7b9669f68d-pzfj4   1/1     Running   0          12s
- ---------------------Second DCI Container PODs created in less 2s-------------------------------
+ oc exec -it dci-dci-container-7b9669f68d-pzfj4 -n dci -- bash -c 'ip a'
4: net1@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default 
    link/ether 94:40:c9:c1:eb:69 brd ff:ff:ff:ff:ff:ff
    inet 192.168.30.21/27 brd 192.168.30.31 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::9440:c900:7c1:eb69/64 scope link 
       valid_lft forever preferred_lft forever
+ oc exec -it dci-dci-container-7b9669f68d-pzfj4 -n dci -- bash -c 'ping -I net1 192.168.30.1'
PING 192.168.30.1 (192.168.30.1) from 192.168.30.21 net1: 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=3.68 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.329 ms       
```
<br />

## Run TNF Test Suite, Helm Chart-Verifier and Preflight Manual, Examples and Links
### TNF Test Suite
### Chart-verifier  
- **Check current-context belong to your CNF Namespace**
  - Edit the kubeconfig then search current-context and update to your CNF application namespace
  - Or use oc config cmd, so if current-context name is not YOURs, then do following:
```bash
#Check Current-Context#
oc config current-context
mvnr-du/api-nokiavf-hubcluster-1-lab-eng-cert-redhat-com:6443/system:admin

#Current-context is NOT avachart#

#Get a list of contexts and search for CNF Namespace#
oc config get-contexts |grep avachart
CURRENT   NAME                                                                                 CLUSTER                                                 AUTHINFO                                                             NAMESPACE
          admin                                                                                nokiavf                                                 admin                                                                
*         avachart/api-nokiavf-hubcluster-1-lab-eng-cert-redhat-com:6443/system:admin          api-nokiavf-hubcluster-1-lab-eng-cert-redhat-com:6443   system:admin/api-nokiavf-hubcluster-1-lab-eng-cert-redhat-com:6443   avachart

#set current-context as in your Namespace#
oc config use-context avachart/api-nokiavf-hubcluster-1-lab-eng-cert-redhat-com:6443/system:admin
```
  
- **Example of run chart-verifier from podman**
```bash
podman run -e KUBECONFIG=/ava/kubeconfig.sno -v ${PWD}:/ava:Z  \
       --rm   quay.io/redhat-certification/chart-verifier verify /ava/samplechart \
       --config /ava/config.yaml -F /ava/values.yaml
```

**Example of running chart-verifier from binary(chart-verifier with set values)**
```bash
BUILD_ID="avachart"
NAMESPACE="avachart"
RELEASE=""
./chart-verifier                                                  \
    verify                                                        \
    --set chart-testing.buildId=${BUILD_ID}                       \
    --set chart-testing.upgrade=false                             \
    --set chart-testing.skipMissingValues=true                    \
    --set chart-testing.namespace=${NAMESPACE}                    \
    --set chart-testing.releaseLabel="app.kubernetes.io/instance" \
    samplechart
```
**Example of running chart-verifier from binary(chart-verifier with --config option)**

**config.yaml:**
```yaml
chart-testing:
    buildId: avachart
    upgrade: false
    skipMissingValues: true
    namespace: avachart
    releaseLabel: "app.kubernetes.io/instance"
```
```bash
./chart-verifier verify --config config.yaml samplechart-0.1.2.tgz
```
**More example of options/arguments can be found in these links:**  
Chart-Verifier homepage: [chart-verifier](https://github.com/redhat-certification/chart-verifier). More Options and examples:
[chart-verifier-opions](https://github.com/redhat-certification/chart-verifier/blob/main/docs/helm-chart-checks.md#chart-testing)  
<br />

**WARNING on Chart-verifier Cache/chart-verifier** 

**Note:** So sometime you updated or modified something on the helm chart, when you re-run the test, it takes the old info from previous data
          that is from this directory the ~/.cache/chart-verifier/.  
          To avoid this issue, you can delete these contents under ~/.cache/chart-verifier/.
```bash
ls -1 ~/.cache/chart-verifier/
samplechart
samplechart_0_1_2_tgz
```

## Start Using DCI to run TNF Test Suite, chart-verifier and preflight to scan Operator or Container images
- **Use DCI to run TNF test Suite**
- **Use DCI to run Chart-Verifier**
- **Use DCI to run Preflight**
