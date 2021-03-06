#!/bin/bash -x

# Commenting out for now.  DB will just get remade each time in the container.
#rm -rf /var/lib/mysql
#mkdir -p /var/lib/mysql

setenforce 0
modprobe ebtables

# Might need this for heat.
# sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8000,8003,8004 --jump ACCEPT

systemctl stop libvirtd

#firewall-cmd --add-service=mysql

# Cleanup from previous runs.  Just for iteration purposes for now.
echo "Removing any running openstack containers.."
containers=`docker ps -qa`
if [ ! -z "$containers" ]; then
    docker ps -qa | xargs docker rm -f
fi

# We need these for the user setup commands.
yum -y install openstack-keystone openstack-glance openstack-nova mariadb

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

# Source openrc for commands
source openrc

######## RABBITMQ ########
echo Starting rabbitmq
docker run -d --name rabbitmq --net=host --env-file=openstack.env kollaglue/centos-rdo-rabbitmq

######## MARIADB ########
echo Starting mariadb
docker run -d --name mariadb --net=host --env-file=openstack.env kollaglue/centos-rdo-mariadb-app

#until mysql -u root --password=kolla --host=$MY_IP mysql -e "show tables;" 2> /dev/null
#do
#    echo waiting for mysql..
#    sleep 3
#done

######## KEYSTONE ########
echo Starting keystone
docker run -d --name keystone --net=host \
       --restart=always \
       --env-file=openstack.env kollaglue/centos-rdo-keystone
#until keystone user-list 2> /dev/null
#do
#    echo waiting for keystone..
#    sleep 3
#done

######## GLANCE ########
echo Starting glance
docker run --name glance-registry --net=host -d --restart=always \
       --env-file=openstack.env rthallisey/fedora-rdo-glance-registry:latest

docker run --name glance-api --net=host -d --restart=always \
       --env-file=openstack.env rthallisey/fedora-rdo-glance-api:latest

######## CINDER ########
echo Starting cinder-iscsi
docker run -d --name cinder-iscsi --net=host \
       --env-file=openstack.env \
       --privileged \
       --restart=always \
       -v /dev:/dev \
       -v /var/lock/iscsi:/var/lock/iscsi \
       -v /var/lib/iscsi:/var/lib/iscsi \
       -v /etc/iscsi:/etc/iscsi \
       -v /lib/modules:/lib/modules \
       -v /var/log:/var/log \
       rthallisey/centos-rdo-cinder-iscsi

echo Starting cinder-api
docker run -d --name cinder-api --net=host \
       --env-file=openstack.env \
       --privileged \
       --restart=always \
       rthallisey/centos-rdo-cinder-api

echo Starting cinder-backup
docker run -d --name cinder-backup --net=host \
       --env-file=openstack.env \
       --privileged \
       --restart=always \
       rthallisey/centos-rdo-cinder-backup

echo Starting cinder-volume
docker run -d --name cinder-volume --net=host \
       --env-file=openstack.env \
       --privileged \
       --restart=always \
       -v /dev:/dev \
       rthallisey/centos-rdo-cinder-volume

echo Starting cinder-scheduler
docker run -d --name cinder-scheduler --net=host \
       --env-file=openstack.env \
       --privileged \
       --restart=always \
       rthallisey/centos-rdo-cinder-scheduler

######## NOVA ########
echo Starting nova-conductor
docker run --name nova-conductor -d \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/centos-rdo-nova-conductor:latest

#until mysql -u root --password=kolla --host=$MY_IP mysql -e "use nova;" 2> /dev/null
#do
#    echo waiting for nova-conductor to create the database..
#    sleep 3
#done

#So this shouldn't really need to be privileged but for some reason
# it is running an iptables command which fails because it doesn't have
#permissions.
echo Starting nova-api
docker run --name nova-api -d --privileged \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/centos-rdo-nova-api:latest

#until keystone user-list | grep nova 2> /dev/null
#do
#    echo waiting for nova-api to create the keystone nova user..
#    sleep 2
#done

# This directory is shared with the host to allow qemu instance
# configs to remain accross restarts.
mkdir -p /etc/libvirt/qemu

# Libvirt is in nova compute for now.
echo Starting libvirt
docker run -d --privileged  \
       --restart=always \
	-v /sys/fs/cgroup:/sys/fs/cgroup \
	-v /var/lib/nova:/var/lib/nova \
	--pid=host --net=host \
	kollaglue/centos-rdo-nova-libvirt

echo Starting nova compute
docker run -d --privileged \
       --restart=always \
       -v /sys/fs/cgroup:/sys/fs/cgroup \
       -v /var/lib/nova:/var/lib/nova \
       -v /run/libvirt:/run/libvirt \
       -v /etc/libvirt/qemu:/etc/libvirt/qemu \
       --pid=host --net=host \
       --env-file=openstack.env kollaglue/centos-rdo-nova-compute-nova:latest

echo Starting nova-network
docker run --name nova-network -d --privileged \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/centos-rdo-nova-network:latest

echo Starting nova-scheduler
docker run --name nova-scheduler -d \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/centos-rdo-nova-scheduler:latest

echo Starting heat-api
docker run --name heat-api -d \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/fedora-rdo-heat-api:latest

echo Starting heat-engine
docker run --name heat-engine -d \
       --restart=always \
       --net=host \
       --env-file=openstack.env kollaglue/fedora-rdo-heat-engine:latest

#echo Starting horizon
#docker run --name horizon -d \
#       --net=host \
#       --env-file=openstack.env kollaglue/fedora-rdo-horizon:latest

IMAGE_URL=http://cdn.download.cirros-cloud.net/0.3.3/
IMAGE=cirros-0.3.3-x86_64-disk.img
if ! [ -f "$IMAGE" ]; then
    curl -o $IMAGE $IMAGE_URL/$IMAGE
fi

#echo "Creating glance image.."
#glance image-create --name "puffy_clouds" --is-public true --disk-format qcow2 --container-format bare --file $IMAGE

#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova network-create vmnet --fixed-range-v4=10.0.0.0/24 --bridge=br100 --multi-host=T

#nova keypair-add mykey > mykey.pem
#chmod 600 mykey.pem
#nova boot --flavor m1.medium --key_name mykey --image puffy_clouds newInstanceName

#docker exec nova-network nova-manage floating create --pool nova --ip_range 172.31.0.128/30
#nova floating-ip-create nova
#nova floating-ip-associate test1 172.31.0.90
