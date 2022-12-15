Table of Contents
=================

* [How to use DCI to Auto-publish Certification Projects](#how-to-use-dci-to-auto-publish-certification-projects)
   * [Purpose](#purpose)
   * [Pre-Requisites](#pre-requisites)
   * [Prepare the setup for auto-publish the container project certification](#prepare-the-setup-for-auto-publish-the-container-project-certification)
      * [Tag and Push Container Images to Registry](#tag-and-push-container-images-to-registry)
      * [Generate DCI Container Images Settings File](#generate-dci-container-images-settings-file)
      * [Start Use DCI to Automate the container image and Auto-Publish](#start-use-dci-to-automate-the-container-image-and-auto-publish)
 
 # How to use DCI to Auto-publish Certification Projects
Normally with DCI we can use Preflight to scan container or operator bundle images for CVE then submit the test results to Connect Portal and remote CI 
remote server GUI. But for other mandatory fields and product-lists are still NOT updated, these unfinished business can be fully automate e2e Auto-Publish.

## Purpose
This MD Will show how prepare and use DCI to create certification project, Update Mandatory Fields, Run Preflight to scan CVE, Attach Product-Listings to Projects
and Finally Auto-publish once all the criteria are met the conditions. 

## Pre-Requisites
- Upgrade the latest DCI Repo
- Include all new changes unofficially since PR is not approved and not started
  Download official-dci-auto-publish.tar and untar to override your original DCI scripts
- Require to have auth.json to communicate to the private registry
- Connect Portal API KEY to use for submit the CVE test results
- OpenShift 4.8x kubeconfig
- Make sure to create container project certification with a details plan how the mandatory fields are describe about your CNF
- Use standard alone preflight to scan container image for CVE and make sure all CVE are passed so it can be automated
- Product-listings Per CNF to be created before hand, this is done only once
- To talk to Quay.io REST API, it requires oauth and bear token

## Prepare the setup for auto-publish the container project certification
### Tag and Push Container Images to Registry
- Tag and push images to private registry using prefix for cnf-type e.g. avacnf
```shellSession
 podman tag dci-container-tpc:v7 quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t1:v1
 podman tag dci-container-tpc:v7 quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t2:v1
 podman push quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t1:v1
 podman push quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t2:v1
 ```
- **Output After Push images to Private Quay Registry**
![Output-Quay-Images](img/quay-images.png "Container Images Listing From Quay")

### Generate DCI Container Images Settings File
using Shellscript to communicate to Quay REST API to get image tag or digest
- **Automate Generate DCI settings.yml file**
```bash
#!/bin/bash
repo_ns=$1    #organization or user-name is either 5gcore or my user-name is avu
cnf_prefix=$2 #quay.ss.bos2.lab/api/v1/repository/avu/amf/amf-ipds:v1 --> amf is cnf prefix
tag_type=$3   #tag type whether imag-name:v1 or imag-name:@sha256-xxxxxxx

if [[ "$repo_ns" == "" || "$cnf_prefix" == "" ]]; then
     echo "Usage: $0 5gcore amf"
     echo "Usage: $0 5gcore amf <name|digest>"
     exit 1
fi

if [[ "$tag_type" == "" ]]; then
     tag_type=name
fi

readarray -t ImageLists <<<$(curl --silent -X GET -H "Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxx" "https://quay.ss.bos2.lab/api/v1/repository?namespace=${repo_ns}"|jq -r '.repositories[].name' | grep ${cnf_prefix})

dci_preflight_settings_file="./settings.yml"
cat settings_head.yml >${dci_preflight_settings_file}

for ((j = 0; j < ${#ImageLists[*]}; j++))
do
   if [[ "$tag_type" == "name" ]]; then
       container_digest=$(curl --silent -X GET -H "Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "https://quay.ss.bos2.lab/api/v1/repository/${repo_ns}/${ImageLists[$j]}" | jq -r '"- container_image: " + "\"quay.ss.bos2.lab/'${repo_ns}'/" + .name + ":" + .tags[].name + "\""')
   else #get digest as tag
       container_digest=$(curl --silent -X GET -H "Authorization: Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "https://quay.ss.bos2.lab/api/v1/repository/${repo_ns}/${ImageLists[$j]}" | jq -r '"- container_image: " + "\"quay.ss.bos2.lab/'${repo_ns}'/" + .name + "@" + .tags[].manifest_digest + "\""')
   fi

   echo "  ${container_digest}" >> ${dci_preflight_settings_file}
   image_name=$(echo $container_digest | cut -d "@" -f1 |sed 's/\"//g'| sed 's/- container_image://g'|cut -d '/' -f3-4)

cat <<EOF >> ${dci_preflight_settings_file}
    create_container_project: true
    short_description: "I am Full-Automation For ${image_name}"
    attach_product_listing: true
EOF
echo >>${dci_preflight_settings_file}
done

cat settings_tail.yml >> ${dci_preflight_settings_file}
```
- **How to run the shellscript**
```shellSession
./ava_generate_dci_preflight_settings.sh avu avacnf digest
./ava_generate_dci_preflight_settings.sh avu avacnf name
```
- **Check the settings.yml content after it automatic generate**
settings.yml:
```yaml
---
dci_topic: OCP-4.11
dci_name: Testing DCI to create certification Project Automatic and Update Settings
dci_configuration: Run Preflight container image and Create Container Project
preflight_test_certified_image: true
partner_creds: "/var/lib/dci-openshift-app-agent/auth.json"
preflight_containers_to_certify:
  - container_image: "quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t1@sha256:7511389e8d9057e9f350dbc907afddda455a367a095a70e392a126b55cacc55f"
    create_container_project: true
    short_description: "I am Full-Automation For avacnf/auto-publish-final-t1"
    attach_product_listing: true

  - container_image: "quay.ss.bos2.lab/avu/avacnf/auto-publish-final-t2@sha256:7511389e8d9057e9f350dbc907afddda455a367a095a70e392a126b55cacc55f"
    create_container_project: true
    short_description: "I am Full-Automation For avacnf/auto-publish-final-t2"
    attach_product_listing: true

cert_settings:
   auto_publish: true
   build_categories: "Standalone image"
   registry_override_instruct: "<p>This is an instruction how to get the image link.</p>"
   email_address: "avu@redhat.com"
   application_categories: "Networking"
   os_content_type: "Red Hat Universal Base Image (UBI)"
   privileged: true
   release_category: "Generally Available"
   repository_description: "This is a test for SS how to automate to create project,SCAN and update settings"

cert_listings:
  published: false
  type: "container stack"
  pyxis_product_list_identifier: "yyyyyyyyyyyyyyyyy"
  
pyxis_apikey_path: "/var/lib/dci-openshift-app-agent/pyxis-apikey.txt"
```
- **Copy newly generated settings.yml to /etc/dci-openshift-app-agent**

**Note:** You dont need to use this shellscript to generate settings.yml you don't have all requirements to run it  
          Example, Quay REST API oauth and bear token, please prepare settings.yml manually as normal.

### Start Use DCI to Automate the container image and Auto-Publish
**Note:** Since new changes on DCI scripts are unofficial to upstream, we can use container image to test since the image included all local updates

- **Pull dci container image with new changes include**
```diff
+ podman pull quay.io/avu0/dci-container-tpc:save
```
- **Run DCI container with podman**
```diff
+ podman run --net=host --privileged -d dci-container-tpc:save sleep infinity
+ podman ps
CONTAINER ID  IMAGE                                  COMMAND         CREATED        STATUS            PORTS       NAMES
b8c3d2a34ed8  quay.io/avu0/dci-container-tpc:save    sleep infinity  4 minutes ago  Up 4 minutes ago              romantic_jang
+ podman exec -it b8c3d2a34ed8 bash
+ su - dci-openshift-app-agent
```

Following are needed to make sure that they prepared and present before start DCI:  
- api-key pyxis-apikey.txt
- Docker Auth.json
- export KUBECONFING=./kubeconfg
- dcirc.sh
- dummy hooks/install.yml
- product-listing ID

```diff
+ dci-openshift-app-agent-ctl -s -- -vvv
```
- **Result from connect Portal**
![Result-From-Auto-Publish](img/auto-publish-result.png "DCI Automate Auto-publish TestResults")
