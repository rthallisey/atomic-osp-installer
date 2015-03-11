#!/bin/bash -x

# Commenting out for now.  DB will just get remade each time in the container.
#rm -rf /var/lib/mysql
#mkdir -p /var/lib/mysql

setenforce 0
modprobe ebtables

systemctl stop libvirtd

# We need these for the user setup commands.
yum -y install openstack-keystone openstack-glance openstack-nova mariadb

# Source openrc for commands
source openrc

echo Starting rabbitmq and mariadb
docker-compose -f rabbitmq.yml up -d
docker-compose -f mariadb up -d

until mysql -u root --password=kolla --host=$MY_IP mysql -e "show tables;"
do
    echo waiting for mysql..
    sleep 3
done

echo Starting keystone
docker-compose -f keystone up -d

until keystone user-list
do
    echo waiting for keystone..
    sleep 3
done

echo Starting glance
docker-compose -f glance-api-registry.yml -d up

echo Starting nova
docker-compose -f nova-api-conductor.yml -d up

# I think we'll need this..
#
# until mysql -u root --password=kolla --host=$MY_IP mysql -e "use nova;"
# do
#     echo waiting for nova db.
#     sleep 3
# done

echo "Waiting for nova-api to create keystone user.."
until keystone user-list | grep nova
do
    echo waiting for keystone nova user
    sleep 2
done

# This directory is shared with the host to allow qemu instance
# configs to remain accross restarts.
mkdir -p /etc/libvirt/qemu

# Libvirt is in nova compute for now.
######## NOVA ########
#echo Starting libvirt
#docker run -d --privileged -p 16509:16509 \
#	-v /sys/fs/cgroup:/sys/fs/cgroup \
#	-v /var/lib/nova:/var/lib/nova \
#	--pid=host --net=host \
#	kollaglue/fedora-rdo-nova-libvirt

echo Starting nova compute

docker-compose -f nova-compute-network.yml up -d

IMAGE_URL=http://download.cirros-cloud.net/0.3.3/
IMAGE=cirros-0.3.3-x86_64-disk.img
if ! [ -f "$IMAGE" ]; then
    curl -o $IMAGE $IMAGE_URL/$IMAGE
fi

echo "Creating glance image.."
glance image-create --name "puffy_clouds" --is-public true --disk-format qcow2 --container-format bare --file $IMAGE

sleep 10

nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
echo "Setting up network.."
nova network-create vmnet --fixed-range-v4=10.0.0.0/24 --bridge=br100 --multi-host=T

#nova keypair-add mykey > mykey.pem
#chmod 600 mykey.pem
#nova boot --flavor m1.medium --key_name mykey --image puffy_clouds newInstanceName
