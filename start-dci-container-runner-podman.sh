#!/bin/bash

print_help() {
    echo "
    ------------------------------------------------------------------------------------------------------------------------
    Usage: bash $0 -tt|--type <PREFLIGHT|TNF|CHART> -pn|--con-name <dci_container_id_name> -sk|--skip-copy <yes|no> -sf|--setting <filename.yml>
    Usage: bash $0 [-h | --help]

    Usage ex: bash $0 --type CHART --con-name 46d79199b0ad --settings-tnf.yml --skip-copy yes/no
              bash $0 --type PREFLIGHT --con-name 46d79199b0ad --settings-tnf.yml

    --setting     --- if not specified settings-xx.yml, it will use default settings.yml, otherwise it will rename to settings.yml.
    --skip-copy   --- default is no, it always needs to copy those requirement files to DCI Container POD.
    --type        --- CHART(chart-verifier), PREFLIGHT and TNF(TNF Test Cert). It can be lower case.
    --con-name    --- Container name or ID where "podman run --net=host --privileged step executed, podman ps"
    --help        --- Usage of the $0
    ------------------------------------------------------------------------------------------------------------------------"
    exit 0
}

for i in "$@"; do
    case $i in
    -cn | --con-name)
        if [ -n "$2" ]; then
            CON_NAME="$2"
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
    -sf | --setting)
        if [ -n "$2" ]; then
            SETTING="$2"
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
if [[ $TEST_TYPE == "" || ${TEST_TYPE} != +(PREFLIGHT|CHART|TNF) || $CON_NAME == "" ]]; then
    print_help
    exit 0
fi

if [[ $SETTING == "" ]]; then
      SETTING="settings.yml"
else
      cp -f $SETTING settings.yml
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

#check OCP accessible caused delaying the api respond
#if oc auth can-i get nodes >/dev/null 2>&1; then
#   logmsg "OCP Access is OK!"
#else
#   echo "OCP Cluster is not accessible, please check permission or kubeconfig ENV"
#   exit 1
#fi

# Next 3 funcs got from David's script
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

# Add checking if these 4 files are present before start copy to the pods
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

# Additional Checking for general files existing or not
for i  in settings.yml dcirc.sh install.yml kubeconfig dci-runner.sh
do
      file_exists "$i" || bye "$i: No such file."
done

# Get CNF name from dci-runner.sh
CNF_NAME=$(grep 'CNF=' dci-runner.sh |cut -d= -f2)
if [[ "$SKIP_COPY" != +(yes|YES) ]]; then
      case $TEST_TYPE in
         CHART)
             logmsg "Copying helm-charts-${CNF_NAME}.yml and auth.json files to ${CON_NAME}:/var/lib/dci-openshift-app-agent"
             podman cp helm_config.yml ${CON_NAME}:/var/lib/dci-openshift-app-agent/helm-charts-${CNF_NAME}.yml
             podman cp auth.json  ${CON_NAME}:/var/lib/dci-openshift-app-agent/auth.json
             ;;
         PREFLIGHT)
             logmsg "Copying pyxis-apikey.txt and auth.json files to ${CON_NAME}:/var/lib/dci-openshift-app-agent"
             podman cp auth.json  ${CON_NAME}:/var/lib/dci-openshift-app-agent/auth.json
             podman cp pyxis-apikey.txt  ${CON_NAME}:/var/lib/dci-openshift-app-agent/pyxis-apikey.txt
             ;;
         *) ;;
     esac
     logmsg "Copying settings.yml, install.yml, dci-runner.sh, dcirc.sh and kubeconfig to ${CON_NAME}"
     podman cp settings.yml ${CON_NAME}:/etc/dci-openshift-app-agent/
     podman cp dcirc.sh ${CON_NAME}:/etc/dci-openshift-app-agent/
     podman cp install.yml  ${CON_NAME}:/etc/dci-openshift-app-agent/hooks/
     podman cp kubeconfig ${CON_NAME}:/var/lib/dci-openshift-app-agent/kubeconfig
     podman cp dci-runner.sh ${CON_NAME}:/var/lib/dci-openshift-app-agent/dci-runner.sh
     podman exec -it ${CON_NAME} /bin/sh -c 'sudo chown -R dci-openshift-app-agent:dci-openshift-app-agent /var/lib/dci-openshift-app-agent/*'
fi

if [[ "$TEST_TYPE" == +(TNF|PREFLIGHT) ]]; then
    # Why remove helm-chart-xx.yml? cuz dci-runner.sh will check if this file existed, then it will run helm chart also with other tests
    logmsg "Removing /var/lib/dci-openshift-app-agent/helm-charts-${CNF_NAME}.yml when not test Chart-Verifier"
    podman exec -it ${CON_NAME} /bin/sh -c "rm /var/lib/dci-openshift-app-agent/helm-charts-${CNF_NAME}.yml" >/dev/null 2>&1
fi

# Clear the dnf cache for Repo Download Issue(Not Fatal) when run dci-runner.sh
podman exec -it ${CON_NAME} /bin/sh -c 'sudo dnf clean all;sudo rm -rf /var/cache/dnf' >/dev/null 2>&1

# Start run dci-agent test remotely from your laptop/other nodes
logmsg "Start DCI Container Runner for ${TEST_TYPE} Testing..."
podman exec -it ${CON_NAME} /bin/sh -c  'su -s /bin/bash -c "export KUBECONFIG=/var/lib/dci-openshift-app-agent/kubeconfig; bash /var/lib/dci-openshift-app-agent/dci-runner.sh" dci-openshift-app-agent'
