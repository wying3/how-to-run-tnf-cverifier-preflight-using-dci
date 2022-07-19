#!/bin/bash

print_help() {
    echo "
         ------------------------------------------------------------------------------------------------------------------------
         Usage: bash $0  -ns|--namespace <NS_Of_Dci_Container> -tt|--type <PREFLIGHT|TNF|CHART> -pn|--podname <Name_Of_DCI_Container_POD> -sk|--skip-copy <yes|no>
	 Usage: bash $0 [-h | --help]
         Usage ex: bash $0 --namespace dci --type CHART --podname dci-dci-container-xxxxx --skip-copy no
                   bash $0 --namespace dci --type PREFLIGHT --podname dci-dci-container-xxxxx
	 
	 --skip-copy   --- default is no, it always needs to copy those requirement files to DCI Container POD.
	 --type        --- CHART(chart-verifier), PREFLIGHT and TNF(TNF Test Cert). It can be lower case.
	 --namespace   --- Namespace of the dci container POD
	 --podname     --- Pod name where dci openshift agent is installed
	 --help        --- Usage of the $0
         ------------------------------------------------------------------------------------------------------------------------"
    exit 0
}

for i in "$@"; do
    case $i in
    -pn | --podname)
        if [ -n "$2" ]; then
            POD_NAME="$2"
            shift 2
            continue
        fi
        ;;
    -tt | --type)
        if [ -n "$2" ]; then
            TEST_TYPE="$2"
            shift 2
            continue
        fi
        ;;
    -ns | --namespace)
        if [ -n "$2" ]; then
            NAMESPACE="$2"
            shift 2
            continue
        fi
        ;;
    -sk | --skip-copy)
        if [ -n "$2" ]; then
            SKIP_COPY="$2"
            shift 2
            continue
        fi
        ;;	
    -h | -\? | --help)
        print_help
        shift #
        ;;
    *)
        # unknown option
        ;;
    esac
done

TEST_TYPE="${TEST_TYPE^^}"
if [[ $TEST_TYPE == "" || ${TEST_TYPE} != +(PREFLIGHT|CHART|TNF) || $POD_NAME == "" || $NAMESPACE == "" ]]; then
    print_help
    exit 0
fi

currpath=$(pwd)
if ! [[ -f "${currpath}/logs" ]]; then
    mkdir -p "$currpath/logs"
fi

SCRIPT=$(basename $0)
NOW=$(date +%Y-%m-%d-%H-%M-%S)
LOGFILE="$currpath/logs/$SCRIPT.log.$NOW"
console="$currpath/logs/$SCRIPT.Console.$NOW"
exec > >(tee -ia $console)
exec 2> >(tee -ia $console >&2)

logmsg() {
    echo "$(date "+%y/%m/%d %H:%M:%S") INFO : $1" >>$LOGFILE
    echo "$(date "+%y/%m/%d %H:%M:%S") INFO : $1"
}

logerr() {
    echo "$(date "+%y/%m/%d %H:%M:%S") ERROR : $1 . Check the logfile under " >>$LOGFILE
    echo "$(date "+%y/%m/%d %H:%M:%S") ERROR : $1 . Check the logfile under $LOGFILE"
    exit 1
}

oc project ${NAMESPACE}
if [ $? -ne 0 ]; then
    echo "OCP Cluster is not accessible, please check it manually!!"
    exit 0
fi

# Checks whether files or directories exist from David's script
file_exists() {
	[ -z "${1-}" ] && bye Usage: file_exists name.
	ls "$1" >/dev/null 2>&1
}
# Prints all parameters and exits with the error code.
bye() {
	log "$*"
	exit 1
}

# Prints all parameters to stdout, prepends with a timestamp.
log() {
	printf '%s %s\n' "$(date +"%Y%m%d-%H:%M:%S")" "$*"
}

##Add checking if these 4 files are present before start copy to the pods##
case $TEST_TYPE in
    CHART)
        file_exists "auth.json" || bye "$i: No such file."
        file_exists "helm_config.yml" || bye "$i: No such file"
	;;
    PREFLIGHT)
        file_exists "auth.json" || bye "$i: No such file."
        file_exists "pyxis-apikey.txt" || bye "$i: No such file."	    
        ;;
    *) ;;
esac

#Additional Checking for general files existing or not#
for i  in settings.yml dcirc.sh install.yml kubeconfig dci-runner.sh
do
      file_exists "$i" || bye "$i: No such file."
done

if [[ "$SKIP_COPY" != +(yes|YES) ]]; then
      case $TEST_TYPE in
         CHART)
	     logmsg "Copying helm-charts-cmm.yml and auth.json files to ${POD_NAME}:/var/lib/dci-openshift-app-agent"
             oc -n $NAMESPACE cp helm_config.yml ${POD_NAME}:/var/lib/dci-openshift-app-agent/helm-charts-cmm.yml
	     oc -n $NAMESPACE cp auth.json  ${POD_NAME}:/var/lib/dci-openshift-app-agent/auth.json
             ;;
         PREFLIGHT)
	     logmsg "Copying pyxis-apikey.txt and auth.json files to ${POD_NAME}:/var/lib/dci-openshift-app-agent"
             oc -n $NAMESPACE cp auth.json  ${POD_NAME}:/var/lib/dci-openshift-app-agent/auth.json
             oc -n $NAMESPACE cp pyxis-apikey.txt  ${POD_NAME}:/var/lib/dci-openshift-app-agent/pyxis-apikey.txt
	     # Why remove helm-chart-xx.yml? cuz dci-runner.sh will check if this file existed, then it will run helm chart also with other test types
             oc -n $NAMESPACE exec -it ${POD_NAME}  -- bash -c 'rm -f /var/lib/dci-openshift-app-agent/helm-charts-cmm.yml' >/dev/null 2>&1	     
             ;;
         *) ;;
     esac
     logmsg "Copying settings.yml, install.yml, dci-runner.sh, dcirc.sh and kubeconfig to ${POD_NAME}:/etc/dci-openshift-app-agent/"
     oc -n $NAMESPACE cp settings.yml ${POD_NAME}:/etc/dci-openshift-app-agent/
     oc -n $NAMESPACE cp dcirc.sh ${POD_NAME}:/etc/dci-openshift-app-agent/
     oc -n $NAMESPACE cp install.yml  ${POD_NAME}:/etc/dci-openshift-app-agent/hooks/
     oc -n $NAMESPACE cp kubeconfig ${POD_NAME}:/var/lib/dci-openshift-app-agent/kubeconfig
     oc -n $NAMESPACE cp dci-runner.sh ${POD_NAME}:/var/lib/dci-openshift-app-agent/dci-runner.sh
     oc -n $NAMESPACE exec -it ${POD_NAME}  -- bash -c 'sudo chown -R dci-openshift-app-agent:dci-openshift-app-agent /var/lib/dci-openshift-app-agent/*'
fi

##Start run dci-agent test remotely from your laptop/other nodes##
logmsg "Start DCI Container Runner for ${TEST_TYPE} Testing Type...."
oc -n $NAMESPACE exec -it ${POD_NAME} -- bash -c 'su - dci-openshift-app-agent -c "export KUBECONFIG=/var/lib/dci-openshift-app-agent/kubeconfig; bash /var/lib/dci-openshift-app-agent/dci-runner.sh"'
