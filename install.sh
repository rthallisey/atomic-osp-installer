#!/bin/bash -x
# Create config and data dirs
#mkdir -p ${HOST}/etc/glance ${HOST}/var/log/glance

# Use as an enviroment variable for service config?
# Copy Config
#cp -p glance.conf ${HOST}/etc/glance/glance.conf

rm -rf /var/lib/mysql
mkdir -p /var/lib/mysql

setenforce 0

docker ps -q | xargs docker stop
docker ps -qa | xargs docker rm

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

# Database
HOST_IP=$MY_IP
MYSQL_ROOT_PASSWORD=kolla
PASSWORD=12345

# Host
ADMIN_TENANT_NAME=admin
PUBLIC_IP=$HOST_IP

# RabbitMQ
RABBITMQ_SERVICE_HOST=$HOST_IP

# Keystone
KEYSTONE_ADMIN_TOKEN=$PASSWORD
KEYSTONE_DB_PASSWORD=kolla
KEYSTONE_ADMIN_PASSWORD=$PASSWORD
KEYSTONE_PUBLIC_SERVICE_HOST=$HOST_IP
KEYSTONE_ADMIN_SERVICE_HOST=$HOST_IP
KEYSTONE_AUTH_PROTOCOL=http

# Glance
GLANCE_DB_NAME=glance
GLANCE_DB_USER=glance
GLANCE_DB_PASSWORD=kolla
GLANCE_KEYSTONE_USER=glance
GLANCE_KEYSTONE_PASSWORD=glance
GLANCE_API_SERVICE_HOST=$HOST_IP

# Nova
NOVA_DB_PASSWORD=nova
NOVA_DB_NAME=nova
NOVA_DB_USER=nova
NOVA_KEYSTONE_USER=nova
NOVA_KEYSTONE_PASSWORD=nova
NOVA_API_SERVICE_HOST=$HOST_IP
NOVA_EC2_SERVICE_HOST=$HOST_IP
NOVA_PUBLIC_INTERFACE=eth0
NOVA_FLAT_INTERFACE=eth0
CONFIG_NETWORK=True


cat > openrc <<EOF
export OS_AUTH_URL="http://${KEYSTONE_PUBLIC_SERVICE_HOST}:5000/v2.0"
export OS_USERNAME=$ADMIN_TENANT_NAME
export OS_PASSWORD=$PASSWORD
export OS_TENANT_NAME=$ADMIN_TENANT_NAME
EOF

# Pull Kolla Containers (can be replaced with atomic install <container>)

echo Starting rabbitmq
docker run --name rabbitmq -d \
        -p 5672:5672 \
        kollaglue/fedora-rdo-rabbitmq

echo Starting mariadb
docker run -d --name mariadb\
	-p 3306:3306 \
	-e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	-v /var/lib/mysql:/var/lib/mysql \
	kollaglue/fedora-rdo-mariadb

sleep 10

echo Starting keystone
docker run -d --name keystone -p 5000:5000 -p 35357:35357 \
	-e MARIADB_SERVICE_HOST=$HOST_IP \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_DB_PASSWORD=$KEYSTONE_DB_PASSWORD \
	-e KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e PUBLIC_IP=$PUBLIC_IP \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	kollaglue/fedora-rdo-keystone:latest

sleep 10

echo Starting glance-registry
docker run --name glance-registry -d \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
	-e GLANCE_DB_NAME=$GLANCE_DB_NAME \
	-e GLANCE_DB_USER=$GLANCE_DB_USER \
	-e GLANCE_KEYSTONE_USER=$GLANCE_KEYSTONE_USER \
	-e KEYSTONE_AUTH_PROTOCOL=$KEYSTONE_AUTH_PROTOCOL \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e GLANCE_KEYSTONE_PASSWORD=$GLANCE_KEYSTONE_PASSWORD \
	-e GLANCE_DB_PASSWORD=$GLANCE_DB_PASSWORD \
	-e MARIADB_SERVICE_HOST=$HOST_IP \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e PUBLIC_IP=$PUBLIC_IP \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
	kollaglue/fedora-rdo-glance-registry:latest

echo Starting glance-api
docker run --name glance-api -d -p 9292:9292 \
        --link 	glance-registry:glance-registry \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
	-e GLANCE_DB_NAME=$GLANCE_DB_NAME \
	-e GLANCE_DB_USER=$GLANCE_DB_USER \
	-e GLANCE_KEYSTONE_USER=$GLANCE_KEYSTONE_USER \
	-e KEYSTONE_AUTH_PROTOCOL=$KEYSTONE_AUTH_PROTOCOL \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e GLANCE_KEYSTONE_PASSWORD=$GLANCE_KEYSTONE_PASSWORD \
	-e GLANCE_DB_PASSWORD=$GLANCE_DB_PASSWORD \
	-e MARIADB_SERVICE_HOST=$HOST_IP \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e KEYSTONE_ADMIN_SERVICE_PORT=5000 \
	-e PUBLIC_IP=$PUBLIC_IP \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
	-e KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD \
	kollaglue/fedora-rdo-glance-api:latest

echo Starting libvirt
sudo docker run -d --privileged \
	-v /sys/fs/cgroup:/sys/fs/cgroup \
	-v /var/lib/nova:/var/lib/nova \
	--pid=host --net=host \
	kollaglue/fedora-rdo-nova-libvirt:latest

echo Starting nova-compute
sudo docker run -d --privileged \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
        -e PUBLIC_IP=$HOST_IP \
	-e NETWORK_MANAGER=nova \
	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	-v /sys/fs/cgroup:/sys/fs/cgroup \
	-v /var/lib/nova:/var/lib/nova \
	--pid=host --net=host \
	kollaglue/fedora-rdo-nova-compute:latest

echo Starting nova-network
sudo docker run -d --privileged \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
        -e PUBLIC_IP=$HOST_IP \
	-e NETWORK_MANAGER=nova \
	-e CONFIG_NETWORK=$CONFIG_NETWORK \
	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	--net=host \
	kollaglue/fedora-rdo-nova-network:latest

echo Starting nova-api

# So this shouldn't really need to be privileged but for some reason
# it is running an iptables command which fails because it doesn't have
# permissions.
sudo docker run -d --privileged \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
	-e NOVA_API_SERVICE_HOST=$NOVA_API_SERVICE_HOST \
	-e NOVA_EC2_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
        -e PUBLIC_IP=$HOST_IP \
	-e NOVA_DB_NAME=$NOVA_DB_NAME \
	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e NETWORK_MANAGER=nova \
	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	kollaglue/fedora-rdo-nova-api:latest

echo Starting nova-conductor
sudo docker run -d \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
	-e NOVA_API_SERVICE_HOST=$NOVA_API_SERVICE_HOST \
	-e NOVA_EC2_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
        -e PUBLIC_IP=$HOST_IP \
	-e NOVA_DB_USER=$NOVA_DB_USER \
	-e NOVA_DB_NAME=$NOVA_DB_NAME \
	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e NETWORK_MANAGER=nova \
	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	-e MARIADB_SERVICE_HOST=$HOST_IP \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	kollaglue/fedora-rdo-nova-conductor:latest

echo Starting nova-scheduler
sudo docker run -d \
	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
	-e NOVA_API_SERVICE_HOST=$NOVA_API_SERVICE_HOST \
	-e NOVA_EC2_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST \
	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
        -e PUBLIC_IP=$HOST_IP \
	-e NOVA_DB_USER=$NOVA_DB_USER \
	-e NOVA_DB_NAME=$NOVA_DB_NAME \
	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
	-e NETWORK_MANAGER=nova \
	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	-e MARIADB_SERVICE_HOST=$HOST_IP \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	kollaglue/fedora-rdo-nova-scheduler:latest
