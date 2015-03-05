#!/bin/bash
# Create config and data dirs
#mkdir -p ${HOST}/etc/glance ${HOST}/var/log/glance

# Use as an enviroment variable for service config?
# Copy Config
#cp -p glance.conf ${HOST}/etc/glance/glance.conf

rm -rf /var/lib/mysql
mkdir -p /var/lib/mysql

setenforce 0

docker ps -q | xargs docker stop

HOST_IP=172.16.209.21
MYSQL_ROOT_PASSWORD=kolla
PASSWORD=12345

KEYSTONE_ADMIN_TOKEN=$PASSWORD
KEYSTONE_DB_PASSWORD=kolla
KEYSTONE_ADMIN_PASSWORD=$PASSWORD
ADMIN_TENANT_NAME=admin
KEYSTONE_PUBLIC_SERVICE_HOST=$HOST_IP
KEYSTONE_ADMIN_SERVICE_HOST=$HOST_IP
PUBLIC_IP=$HOST_IP

# Pull Kolla Containers (can be replaced with atomic install <container>)
docker run -d kollaglue/fedora-rdo-rabbitmq
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -v /var/lib/mysql:/var/lib/mysql kollaglue/fedora-rdo-mariadb

sleep 10

docker run -d -p 5000:5000 -p 35357:35357 -e MARIADB_SERVICE_HOST=$HOST_IP -e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN -e KEYSTONE_DB_PASSWORD=$KEYSTONE_DB_PASSWORD -e KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD -e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME -e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST -e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST -e PUBLIC_IP=$PUBLIC_IP -e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD kollaglue/fedora-rdo-keystone

# sudo docker run -d --privileged -e "KEYSTONE_ADMIN_TOKEN=$PASSWORD" -e "NOVA_DB_PASSWORD=$PASSWORD" -e "RABBIT_PASSWORD=$PASSWORD" -e "RABBIT_USERID=stackrabbit" -e NETWORK_MANAGER="nova" -e "GLANCE_API_SERVICE_HOST=$SERVICE_HOST" -e "KEYSTONE_PUBLIC_SERVICE_HOST=$SERVICE_HOST" -e "RABBITMQ_SERVICE_HOST=$SERVICE_HOST" -e "NOVA_KEYSTONE_PASSWORD=$PASSWORD" -v /sys/fs/cgroup:/sys/fs/cgroup -v /var/lib/nova:/var/lib/nova -v /var/run/dbus:/var/run/dbus --pid=host --net=host imain/fedora-rdo-nova-compute

