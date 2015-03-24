#!/bin/bash

declare -a containers
containers=(centos-rdo-rabbitmq
	    centos-rdo-mariadb
	    centos-rdo-keystone
	    centos-rdo-glance-api
	    centos-rdo-glance-registry
	    centos-rdo-nova-conductor
	    centos-rdo-nova-api
	    centos-rdo-nova-compute
	    centos-rdo-nova-scheduler
#	    centos-rdo-heat-engine
#	    centos-rdo-heat-api
	   )

REGISTRY_PORT=8080
IP=10.18.57.151

#echo $containers
for i in "${containers[@]}"; do 
    sudo docker pull kollaglue/$i
done

for i in "${containers[@]}"; do 
    sudo docker tag kollaglue/$i $IP:$REGISTRY_PORT/$i
done

for i in "${containers[@]}"; do 
    sudo docker push $IP:$REGISTRY_PORT/$i
done
