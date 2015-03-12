FROM fedora
MAINTAINER Ryan Hallisey <rhallise@redhat.com>
ENV container openstack
RUN yum update -y; yum clean all

LABEL INSTALL="docker run --rm --privileged -v /:/host --env-file=openstack.env -e HOST=/host -e IMAGE=IMAGE -e NAME=NAME IMAGE /usr/bin/start.sh"

ADD start.sh /usr/bin/start.sh
