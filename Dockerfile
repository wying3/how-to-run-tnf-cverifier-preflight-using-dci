ARG OPENSHIFT_CLIENT_VERSION=4.9.25
FROM registry.access.redhat.com/ubi8/ubi:latest
LABEL name="DCI runs TNF, Preflight and ChartVerifier" \
      maintainer="dcicontainer.scm@redhat.com" \
      vendor="Red Hat, Inc." \
      version="1" \
      release="" \
      summary="Use DCI to run preflight, chart-verifier and tnf" \
      description="Use DCI to run Preflight, Chart-Verifier and TNF Test Suite inside a container"

RUN mkdir -p /licenses
COPY LICENSE /licenses/License.txt

RUN dnf -y update --disablerepo=* --enablerepo=ubi-8-appstream --enablerepo=ubi-8-baseos \
    && dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
    && dnf -y install https://packages.distributed-ci.io/dci-release.el8.noarch.rpm \
    && dnf -y reinstall shadow-utils; dnf -y install python3-kubernetes wget procps crun iputils iproute bzip2 iptables net-tools openscap-utils podman fuse-overlayfs --exclude container-selinux \
    && dnf -y install ansible --enablerepo=ansible-2.9-for-rhel-8-x86_64-rpms --disablerepo=epel \
    && dnf -y install dci-openshift-app-agent \
    && dnf clean all; yum clean all \
    && rm -rf /var/cache /var/log/dnf* /var/log/yum.* /var/log/* \
    && mkdir -p /var/log/rhsm; rm -rf /var/cache/dnf

RUN useradd podman; \
    echo podman:10000:5000 > /etc/subuid; \
    echo podman:10000:5000 > /etc/subgid; \
    echo dci-openshift-app-agent:100000:65536 >> /etc/subuid; \
    echo dci-openshift-app-agent:100000:65536 >> /etc/subgid;

VOLUME /var/lib/containers /home/podman/.local/share/containers

ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/podman/.config/containers/containers.conf

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chown podman:podman -R /home/podman \ 
    && chmod 644 /etc/containers/containers.conf \
    && sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf \
    && mkdir -p /var/lib/shared/{overlay-images,overlay-layers,vfs-images,vfs-layers} \
    && touch /var/lib/shared/overlay-images/images.lock /var/lib/shared/overlay-layers/layers.lock /var/lib/shared/vfs-images/images.lock /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

# Install OpenShift client binary
ARG OPENSHIFT_CLIENT_VERSION
RUN curl --fail -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_CLIENT_VERSION}/openshift-client-linux-${OPENSHIFT_CLIENT_VERSION}.tar.gz | tar -xzv -C /usr/local/bin oc

