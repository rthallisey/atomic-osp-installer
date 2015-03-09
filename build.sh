#!/bin/bash -x

for i in fedora-rdo-base glance/glance-base glance/glance-api glance/glance-registry
do
   pushd fig/docker/$i
   pwd
   echo sudo ./build -n imain -t latest
   sudo ./build -n imain -t latest
   popd
done

for i in mariadb rabbitmq keystone \
         nova-base nova-controller/nova-api nova-controller/nova-conductor nova-controller/nova-scheduler \
         nova-compute/nova-compute nova-compute/nova-network
do
    pushd kolla/docker/$i
    pwd
    echo sudo ./build -n imain -t latest
    sudo ./build -n imain -t latest
    popd
done

