FROM fedora
MAINTAINER Ryan Hallisey <rhallise@redhat.com>
ENV container openstack
RUN yum update -y; yum install -y git; yum clean all

RUN git clone https://github.com/stackforge/kolla.git

LABEL INSTALL="docker run --rm --privileged -v /:/host -e HOST=/host -e LOGDIR=${LOGDIR} -e CONFDIR=${CONFDIR} -e DATADIR=${DATADIR} -e IMAGE=IMAGE -e NAME=NAME IMAGE /bin/install.sh"
ADD install.sh /usr/bin/install.sh
