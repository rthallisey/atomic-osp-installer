#!/bin/bash
# Create config and data dirs
#mkdir -p ${HOST}/etc/glance ${HOST}/var/log/glance

# Use as an enviroment variable for service config?
# Copy Config
#cp -p glance.conf ${HOST}/etc/glance/glance.conf

# Pull Kolla Containers (can be replaced with atomic install <container>)
chroot ${HOST} docker pull kollaglue/fedora-rdo-rabbitmq
chroot ${HOST} docker pull kollaglue/fedora-rdo-mariadb
chroot ${HOST} docker pull kollaglue/fedora-rdo-keystone
