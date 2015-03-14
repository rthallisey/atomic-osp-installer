#!/bin/bash -x

# Commenting out for now.  DB will just get remade each time in the container.
#rm -rf /var/lib/mysql
#mkdir -p /var/lib/mysql

export HOME=/root

# Disable selinux on the host
chroot ${HOST} setenforce 0

chroot ${HOST} modprobe ebtables

#systemctl stop libvirtd

#firewall-cmd --add-service=mysql

# We need these for the user setup commands.
#yum -y install openstack-keystone openstack-glance openstack-nova mariadb

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')
MY_DEV=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $3}')

echo MY_IP=$MY_IP
echo MY_DEV=$MY_DEV

genenv.sh
cp openrc /etc/openrc
cp openstack.env /etc/openstack.env

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
       -v /run:/run \
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

IMAGE_URL=http://cdn.download.cirros-cloud.net/0.3.3/
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
