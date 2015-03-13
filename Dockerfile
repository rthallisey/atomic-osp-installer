FROM fedora
MAINTAINER Ryan Hallisey <rhallise@redhat.com>
ENV container openstack
RUN yum update -y; yum -y install docker mariadb openstack-keystone openstack-nova-compute openstack-glance iproute; yum -y clean all

LABEL INSTALL="docker run --rm --privileged --net=host -v /:/host -v /var/lib:/var/lib -v /run:/run --env-file=openstack.env -e HOST=/host -e IMAGE=IMAGE -e NAME=NAME --name NAME IMAGE /usr/bin/atomic-start.sh"
LABEL RUN="echo please execute atomic install IMAGE"

ADD atomic-start.sh /usr/bin/atomic-start.sh
