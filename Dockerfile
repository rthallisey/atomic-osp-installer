FROM fedora
MAINTAINER Ryan Hallisey <rhallise@redhat.com>
ENV container openstack
RUN yum update -y; yum install -y git; yum clean all

LABEL INSTALL="docker run --rm --privileged -v /:/host -e HOST=/host -e LOGDIR=${LOGDIR} -e CONFDIR=${CONFDIR} -e DATADIR=${DATADIR} -e IMAGE=IMAGE -e NAME=NAME IMAGE /usr/bin/install.sh"

LABEL INSTALL="docker pull kollaglue/fedora-rdo-keystone"
LABEL RUN="docker run --rm --priveleged kollaglue/fedora-rdo-keystone"
LABEL STOP="docker stop"
LABEL UNINSTALL="docker rmi kollaglue/fedora-rdo-keystone"

ADD install.sh /usr/bin/install.sh
