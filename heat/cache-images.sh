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

local registry_port=8080

#echo $containers
for i in "${containers[@]}"; do 
    echo sudo docker pull kollaglue/$i
done

for i in "${containers[@]}"; do 
    echo sudo docker tag kollaglue/$i localhost:$registry_port/$i
done

for i in "${containers[@]}"; do 
    echo sudo docker push localhost:$registry_port/$i
done
