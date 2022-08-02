#!/bin/sh
# Disables shellcheck warning about using local variables.
# shellcheck disable=SC3043

# Global variables could be used in functions.
CNF=cmm
MAN='Usage: dci-runner.sh.'
VER=0.9.20220626-nokia

# Prints all parameters to stdout, prepends with a timestamp.
log() {
	printf '%s %s\n' "$(date +"%Y%m%d-%H:%M:%S")" "$*"
}

# Prints all parameters and exits with the error code.
bye() {
	log "$*"
	exit 1
}

# Checks if applications are installed. Loops over the arguments, each one is an
# application name.
validate_cmd() {
	[ -z "${1-}" ] || [ $# -eq 0 ] && bye Usage: validate_cmd cmd1 cmd2...
	local arg
	for arg do
		command -v "$arg" >/dev/null 2>&1 || bye "Install $arg."
	done
}

# Checks if environment variables are defined. Loops over the arguments, each
# one is a variable name.
validate_var() {
	[ -z "${1-}" ] || [ $# -eq 0 ] && bye Usage: validate_var var1 var2...
	log Environment variables:
	local arg
	for arg do
		set +u
		local var
		eval "var=\${$arg}"
		set -u
		[ -z "${var}" ] && bye "Define $arg."
		log "  $arg=$var"
	done
}

# Exits with error if it is not ran by a user.
be_user() {
	[ -z "${1-}" ] && bye Usage: be_user name.
	local ask cur usr="$1"
	cur="$(id -u)"
	ask="$(id -u "$usr" 2>/dev/null)" || bye "$usr: no such user."
	[ "$ask" -ne "$cur" ] && bye "You are $(id -un) ($cur), be $usr ($ask)."
}

# Checks whether files or directories exist.
file_exists() {
	[ -z "${1-}" ] && bye Usage: file_exists name.
	ls "$1" >/dev/null 2>&1
}

# Composes Ansible parameters for Helm Charts tests.
helm_charts_param() {
	local cfg
	cfg="$(dirname "$(realpath "$0")")/helm-charts-$CNF.yml"
	file_exists "$cfg" || return 0
	printf -- " \
--extra-vars \"kubeconfig_path\"=\"%s\" \
--extra-vars \"do_chart_verifier\"=\"true\" \
--extra-vars \"@%s\"\
" \
		"$KUBECONFIG" \
		"$cfg"
}

# Adds environment variables for DCI if a resource file exists.
resource() {
	local rc=/etc/dci-openshift-app-agent/dcirc.sh
	file_exists $rc || return 0
	# shellcheck disable=SC1090
	. $rc
	log Uses resource $rc.
}

# Starting point.
be_user dci-openshift-app-agent

# The settings file is expected to be.
CFG=/etc/dci-openshift-app-agent/settings.yml
file_exists "$CFG" || bye "$CFG: No such file. $MAN"
resource
validate_cmd \
	ansible \
	dci-openshift-app-agent-ctl \
	dnf \
	podman \
	oc
validate_var \
	DCI_API_SECRET \
	DCI_CLIENT_ID \
	DCI_CS_URL \
	KUBECONFIG
file_exists "$KUBECONFIG" || bye "$KUBECONFIG: No such file."

# Gets local system information for DCI tags.
CNF_NAME="CNF:$CNF"
TIMESTAMP="Timestamp:$(date +%Y%m%d-%H:%M:%S)"
TNF_CFG=/usr/share/dci-openshift-app-agent/roles/cnf-cert/defaults/main.yml
TNF_VERSION="TNF:$(cat $TNF_CFG | \
	grep test_network_function_version | \
	awk '{printf $2}' | \
	tr -d '"')"
DCI_AGENT_VERSION="Agent:$(dnf list | \
	grep dci-openshift-app-agent -m1 | \
	awk '{print $2}' | \
	awk -F "-" '{print $1}')"
PODMAN_VERSION="Podman:$(podman --version | awk '{print $3}')"

# Parses different Ansible version formats:
#  ansible [core 2.12.1]
#  ansible 2.9.27
# sed removes [ and ] if exist, awk prints the last column.
ANSIBLE_VERSION="Ansible:$(ansible --version 2>/dev/null | \
	head -1 | \
	sed 's/\[//;s/\]//' | \
	awk '{printf $NF}')"
OC_CLIENT_VERSION="OC Client:$(oc version | grep "Client" | awk '{print $3}')"
RHCOS_VERSION="RHCOS:$(oc adm release info \
	-o 'jsonpath={.displayVersions.machine-os.Version}')"
KUBE_VERSION="Kube:$(oc version | grep "Kubernetes" | awk '{print $3}')"
RUNNER_VERSION="Runner:$VER"
log DCI tags:
log "  $CNF_NAME"
log "  $TIMESTAMP"
log "  $TNF_VERSION"
log "  $DCI_AGENT_VERSION"
log "  $PODMAN_VERSION"
log "  $ANSIBLE_VERSION"
log "  $OC_CLIENT_VERSION"
log "  $RHCOS_VERSION"
log "  $KUBE_VERSION"
log "  $RUNNER_VERSION"
TAGS="\
\"$CNF_NAME\",\
\"$TIMESTAMP\",\
\"$TNF_VERSION\",\
\"$DCI_AGENT_VERSION\",\
\"$PODMAN_VERSION\",\
\"$ANSIBLE_VERSION\",\
\"$OC_CLIENT_VERSION\",\
\"$RHCOS_VERSION\",\
\"$KUBE_VERSION\",\
\"$RUNNER_VERSION\""

# shellcheck disable=SC2046
dci-openshift-app-agent-ctl \
	--start \
	--config "$CFG" \
	-- \
	--extra-vars \{\"dci_tags\":["$TAGS"]\}$(helm_charts_param)
log Bye.

