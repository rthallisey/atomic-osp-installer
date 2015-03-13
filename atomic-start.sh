#!/bin/bash -x

# Commenting out for now.  DB will just get remade each time in the container.
#rm -rf /var/lib/mysql
#mkdir -p /var/lib/mysql

export HOME=/root

#setenforce 0
chroot ${HOST} modprobe ebtables

#systemctl stop libvirtd

#firewall-cmd --add-service=mysql

# Cleanup from previous runs.  Just for iteration purposes for now.
#echo "Removing any running openstack containers.."
#containers=`docker ps -qa`
#if [ ! -z "$containers" ]; then
#    docker ps -qa | xargs docker rm -f
#fi

# We need these for the user setup commands.
#yum -y install openstack-keystone openstack-glance openstack-nova mariadb

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')
MY_DEV=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $3}')

echo MY_IP=$MY_IP
echo MY_DEV=$MY_DEV

# Database
HOST_IP=$MY_IP
MYSQL_ROOT_PASSWORD=kolla
PASSWORD=12345

# Host
ADMIN_TENANT_NAME=admin
PUBLIC_IP=$HOST_IP

# RabbitMQ
RABBITMQ_SERVICE_HOST=$HOST_IP
RABBIT_USER=guest
RABBIT_PASSWORD=guest

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
NOVA_PUBLIC_INTERFACE=$MY_DEV
NOVA_FLAT_INTERFACE=$MY_DEV
CONFIG_NETWORK=True

cat > /etc/openrc <<EOF
export OS_AUTH_URL="http://${KEYSTONE_PUBLIC_SERVICE_HOST}:5000/v2.0"
export OS_USERNAME=$ADMIN_TENANT_NAME
export OS_PASSWORD=$PASSWORD
export OS_TENANT_NAME=$ADMIN_TENANT_NAME
EOF

cat > /etc/openstack.env <<EOF
ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME
CONFIG_NETWORK=$CONFIG_NETWORK
DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
FLAT_INTERFACE=$NOVA_FLAT_INTERFACE
GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST
GLANCE_DB_NAME=$GLANCE_DB_NAME
GLANCE_DB_PASSWORD=$GLANCE_DB_PASSWORD
GLANCE_DB_USER=$GLANCE_DB_USER
GLANCE_KEYSTONE_PASSWORD=$GLANCE_KEYSTONE_PASSWORD
GLANCE_KEYSTONE_USER=$GLANCE_KEYSTONE_USER
KEYSTONE_ADMIN_PASSWORD=$KEYSTONE_ADMIN_PASSWORD
KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST
KEYSTONE_ADMIN_SERVICE_PORT=5000
KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN
KEYSTONE_AUTH_PROTOCOL=$KEYSTONE_AUTH_PROTOCOL
KEYSTONE_DB_PASSWORD=$KEYSTONE_DB_PASSWORD
KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST
MARIADB_SERVICE_HOST=$HOST_IP
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
NETWORK_MANAGER=nova
NOVA_API_SERVICE_HOST=$NOVA_API_SERVICE_HOST
NOVA_DB_NAME=$NOVA_DB_NAME
NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD
NOVA_DB_USER=$NOVA_DB_USER
NOVA_EC2_API_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST
NOVA_EC2_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST
NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD
NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER
PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE
PUBLIC_IP=$HOST_IP
PUBLIC_IP=$PUBLIC_IP
RABBITMQ_PASS=$RABBIT_PASSWORD
RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST
RABBITMQ_USER=$RABBIT_USER
RABBIT_PASSWORD=$RABBIT_PASSWORD
RABBIT_USERID=$RABBIT_USER
EOF

# Source openrc for commands
source /etc/openrc
cp /etc/openstack.env ${HOST}/etc/openstack.env

######## RABBITMQ ########
echo Starting rabbitmq
# atomic install fedora-rdo-rabbitmq-atomic
docker run -d --name rabbitmq -p 5672:5672 --env-file=/etc/openstack.env imain/fedora-rdo-rabbitmq

######## MARIADB ########
echo Starting mariadb
#rm -rf /var/lib/mysql
mkdir -p ${HOST}/var/lib/mysql
mkdir -p ${HOST}/var/log/mariadb

docker run -d --name mariadb --net=host -v /var/lib/mysql:/var/lib/mysql:Z -v /var/log/mariadb:/var/log/mariadb:Z --env-file=/etc/openstack.env imain/fedora-rdo-mariadb

until mysql -u root --password=kolla mysql -e "show tables;"
do
    echo waiting for mysql..
    sleep 3
done

######## KEYSTONE ########
echo Starting keystone
docker run -d --name keystone --net=host \
       --env-file=/etc/openstack.env imain/fedora-rdo-keystone
until keystone user-list
do
    echo waiting for keystone..
    sleep 3
done

######## GLANCE ########
echo Starting glance
docker run --name glance-registry --net=host -d \
       --env-file=/etc/openstack.env rthallisey/fedora-rdo-glance-registry:latest

docker run --name glance-api -d --net=host \
       --link glance-registry:glance-registry \
       --link rabbitmq:rabbitmq \
       --env-file=/etc/openstack.env rthallisey/fedora-rdo-glance-api:latest

######## NOVA ########
echo Starting nova-conductor
docker run --name nova-conductor -d --net=host\
       --env-file=/etc/openstack.env imain/fedora-rdo-nova-conductor:latest

until mysql -u root --password=kolla --host=$MY_IP mysql -e "use nova;"
do
    echo waiting for nova-conductor to create the database..
    sleep 3
done

#So this shouldn't really need to be privileged but for some reason
# it is running an iptables command which fails because it doesn't have
#permissions.
echo Starting nova-api
docker run --name nova-api -d --privileged --net=host \
       --env-file=/etc/openstack.env imain/fedora-rdo-nova-api:latest

until keystone user-list | grep nova
do
    echo waiting for nova-api to create the keystone nova user..
    sleep 2
done

# This directory is shared with the host to allow qemu instance
# configs to remain accross restarts.
 mkdir -p /etc/libvirt/qemu

# Libvirt is in nova compute for now.
#echo Starting libvirt
#docker run -d --privileged -p 16509:16509 \
#	-v /sys/fs/cgroup:/sys/fs/cgroup \
#	-v /var/lib/nova:/var/lib/nova \
#	--pid=host --net=host \
#	kollaglue/fedora-rdo-nova-libvirt

echo Starting nova compute
docker run -d --privileged \
       -v /sys/fs/cgroup:/sys/fs/cgroup \
       -v /var/lib/nova:/var/lib/nova \
       -v /run/libvirt:/run/libvirt \
       -v /etc/libvirt/qemu:/etc/libvirt/qemu \
       --pid=host --net=host \
       --env-file=/etc/openstack.env imain/fedora-rdo-nova-compute:latest

echo Starting nova-network
docker run --name nova-network -d --privileged \
       --net=host \
       --env-file=/etc/openstack.env imain/fedora-rdo-nova-network:latest

echo Starting nova-scheduler
docker run --name nova-scheduler -d --net=host \
       --env-file=/etc/openstack.env imain/fedora-rdo-nova-scheduler:latest

IMAGE_URL=http://download.cirros-cloud.net/0.3.3/
IMAGE=cirros-0.3.3-x86_64-disk.img
if ! [ -f "$IMAGE" ]; then
    curl -o $IMAGE $IMAGE_URL/$IMAGE
fi

sleep 5

#echo "Creating glance image.."
glance image-create --name "puffy_clouds" --is-public true --disk-format qcow2 --container-format bare --file $IMAGE


#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#echo "Setting up network.."
#nova network-create vmnet --fixed-range-v4=10.0.0.0/24 --bridge=br100 --multi-host=T

#nova keypair-add mykey > mykey.pem
#chmod 600 mykey.pem
#nova boot --flavor m1.medium --key_name mykey --image puffy_clouds newInstanceName
