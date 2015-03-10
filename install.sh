#!/bin/bash -x

# Commenting out for now.  DB will just get remade each time in the container.
#rm -rf /var/lib/mysql
#mkdir -p /var/lib/mysql

setenforce 0
modprobe ebtables

MY_IP=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $5}')

MY_DEV=$(ip route get $(ip route | awk '$1 == "default" {print $3}') |
    awk '$4 == "src" {print $3}')

echo MY_IP=$MY_IP
echo MY_DEV=$MY_DEV

# Cleanup from previous runs.  Just for iteration purposes for now.
containers=`docker ps -q`
if [ ! -z "$containers" ]; then
    docker ps -q | xargs docker stop
fi

containers=`docker ps -qa`
if [ ! -z "$containers" ]; then
    docker ps -qa | xargs docker rm
fi


firewall-cmd --add-service=mysql

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
NOVA_PUBLIC_INTERFACE=$MY_DEV
NOVA_FLAT_INTERFACE=$MY_DEV
CONFIG_NETWORK=True

# We need these for the external setup commands.
yum -y install openstack-keystone openstack-glance openstack-nova

cat > openrc <<EOF
export OS_AUTH_URL="http://${KEYSTONE_PUBLIC_SERVICE_HOST}:5000/v2.0"
export OS_USERNAME=$ADMIN_TENANT_NAME
export OS_PASSWORD=$PASSWORD
export OS_TENANT_NAME=$ADMIN_TENANT_NAME
EOF

# Source it now for commands..
source openrc

# Pull Kolla Containers (can be replaced with atomic install <container>)

######## RABBITMQ ########
echo Starting rabbitmq
docker run --name rabbitmq -d \
        -p 5672:5672 \
	kollaglue/fedora-rdo-rabbitmq

# Add to bind mount mysql dir to host.
#-v /var/lib/mysql:/var/lib/mysql \

######## MARIADB ########
echo Starting mariadb
docker run -d --name mariadb\
	-p 3306:3306 \
	-e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	kollaglue/fedora-rdo-mariadb

until mysql -u root --password=kolla --host=$MY_IP mysql -e "show tables;"
do
    echo waiting for mysql..
    sleep 3
done

######## KEYSTONE ########
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
	kollaglue/fedora-rdo-keystone

until keystone user-list
do
    echo waiting for keystone..
    sleep 3
done

######## GLANCE ########
echo Starting glance-registry
docker run --name glance-registry -p 9191:9191 -d \
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
	rthallisey/fedora-rdo-glance-registry:latest

echo Starting glance-api
docker run --name glance-api -d -p 9292:9292 \
        --link 	glance-registry:glance-registry \
        --link 	rabbitmq:rabbitmq \
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
	rthallisey/fedora-rdo-glance-api:latest

echo Starting nova-conductor
docker run --name nova-conductor -d \
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
 	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
 	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	imain/fedora-rdo-nova-conductor:latest

until mysql -u root --password=kolla --host=$MY_IP mysql -e "use nova;"
do
    echo waiting for nova db.
    sleep 3
done

echo Starting nova-api
#So this shouldn't really need to be privileged but for some reason
# it is running an iptables command which fails because it doesn't have
#permissions.
docker run --name nova-api -d --privileged -p 8774:8774 \
 	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
 	-e KEYSTONE_ADMIN_SERVICE_HOST=$KEYSTONE_ADMIN_SERVICE_HOST \
 	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
 	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
 	-e NOVA_API_SERVICE_HOST=$NOVA_API_SERVICE_HOST \
 	-e NOVA_EC2_API_SERVICE_HOST=$NOVA_EC2_SERVICE_HOST \
	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
 	-e MARIADB_SERVICE_HOST=$HOST_IP \
 	-e ADMIN_TENANT_NAME=$ADMIN_TENANT_NAME \
        -e PUBLIC_IP=$HOST_IP \
 	-e NOVA_DB_NAME=$NOVA_DB_NAME \
 	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
 	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
 	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
 	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
 	-e NETWORK_MANAGER=nova \
 	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
 	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
	imain/fedora-rdo-nova-api:latest

echo "Waiting for nova-api to create keystone user.."
until keystone user-list | grep nova
do
    echo waiting for keystone nova user
    sleep 2
done


# mkdir -p /etc/libvirt

# Libvirt is in nova compute for now.
######## NOVA ########
#echo Starting libvirt
#docker run -d --privileged -p 16509:16509 \
#	-v /sys/fs/cgroup:/sys/fs/cgroup \
#	-v /var/lib/nova:/var/lib/nova \
#	--pid=host --net=host \
#	kollaglue/fedora-rdo-nova-libvirt

echo Starting nova-compute
docker run --name nova-compute -d --privileged \
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
	-v /run/libvirt:/run/libvirt \
	--pid=host --net=host \
	imain/fedora-rdo-nova-compute:latest

#	-v /etc/libvirt:/etc/libvirt \

echo Starting nova-network
docker run --name nova-network -d --privileged \
 	-e KEYSTONE_ADMIN_TOKEN=$KEYSTONE_ADMIN_TOKEN \
 	-e NOVA_DB_PASSWORD=$NOVA_DB_PASSWORD \
 	-e RABBITMQ_SERVICE_HOST=$RABBITMQ_SERVICE_HOST \
 	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
 	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
 	-e NOVA_KEYSTONE_USER=$NOVA_KEYSTONE_USER \
 	-e NOVA_KEYSTONE_PASSWORD=$NOVA_KEYSTONE_PASSWORD \
 	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
 	-e PUBLIC_IP=$HOST_IP \
 	-e NETWORK_MANAGER=nova \
 	-e CONFIG_NETWORK=$CONFIG_NETWORK \
 	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
 	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
 	--net=host \
 	imain/fedora-rdo-nova-network:latest

echo Starting nova-scheduler
docker run --name nova-scheduler -d \
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
 	-e GLANCE_API_SERVICE_HOST=$GLANCE_API_SERVICE_HOST \
 	-e KEYSTONE_PUBLIC_SERVICE_HOST=$KEYSTONE_PUBLIC_SERVICE_HOST \
 	-e NETWORK_MANAGER=nova \
 	-e PUBLIC_INTERFACE=$NOVA_PUBLIC_INTERFACE \
 	-e FLAT_INTERFACE=$NOVA_FLAT_INTERFACE \
 	-e MARIADB_SERVICE_HOST=$HOST_IP \
 	-e DB_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
	imain/fedora-rdo-nova-scheduler:latest

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
