FROM fedora
MAINTAINER Ryan Hallisey <rhallise@redhat.com>
ENV container openstack
RUN yum update -y; yum -y install mariadb openstack-keystone openstack-nova-compute openstack-glance iproute; yum -y clean all

LABEL INSTALL="docker run --rm --privileged --net=host -v /:/host --env-file=openstack.env -e HOST=/host -e IMAGE=IMAGE -e NAME=NAME --name NAME IMAGE /usr/bin/atomic-start.sh"

ADD atomic-start.sh /usr/bin/atomic-start.sh
ADD openstack.env /etc/openstack.env
ADD openrc /etc/openrc
