#!/bin/bash -x

# declare -a containers
# containers=(atomic-install-rabbitmq
# 	    atomic-install-mariadb
# 	    atomic-install-keystone
# 	    atomic-install-glance-api
# 	    atomic-install-glance-registry
# 	    atomic-install-nova-conductor
# 	    atomic-install-nova-api
# 	    atomic-install-nova-libvirt
# 	    atomic-install-nova-compute
# 	    atomic-install-nova-scheduler
# 	    atomic-install-nova-network
# #	    atomic-install-heat-engine
# #	    atomic-install-heat-api
# 	   )
#
REGISTRY_PORT=8080
IP=10.18.57.202
#
# #echo $containers
# # for i in "${containers[@]}"; do
# #     sudo docker pull imain/$i
# # done
#
# for i in "${containers[@]}"; do
#     sudo docker tag -f imain/$i $IP:$REGISTRY_PORT/$i
# done
#
# for i in "${containers[@]}"; do
#     sudo docker push $IP:$REGISTRY_PORT/$i
# done

HEAT_REPO=ramishra
HEAT_IMAGE=heat-docker-atomic-agents

sudo docker pull $HEAT_REPO/$HEAT_IMAGE
sudo docker tag -f $HEAT_REPO/$HEAT_IMAGE $IP:$REGISTRY_PORT/$HEAT_IMAGE
sudo docker push $IP:$REGISTRY_PORT/$HEAT_IMAGE

