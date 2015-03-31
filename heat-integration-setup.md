# Heat integration setup
In order to use heat to deploy a containerized tripleo, there are a few things required.  First, we are using devstack to function as the undercloud.
```
git clone https://git.openstack.org/openstack-dev/devstack
cd devstack; ./stack.sh
```

After devstack completes, nova needs a little adjusting to allow for nested virt.  Make sure you have no VMs running.
```
sudo rmmod kvm-intel
sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
sudo modprobe kvm-intel
```

In order for nova to put /dev/kvm on the rhel-atomic host you need to edit the nova config.
```
cpu mode=host-passthrough
```

Restart nova and check your atomic host and check that /dev/kvm exists.
Nova instances requires these rules to ssh into them:
```
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
```

Create a local docker registry to cache the images. You can choose the port this will the registry will use. In the example we use 8080 instead of 5000 (default) because keystone will be using 5000.
```
sudo yum install docker-registry
sudo systemctl start docker-registry
```

Then run the build and cache scripts to pull the images, tag, and push them to the local registry.
```
cd dockerfiles; sudo ./build; cd ../heat; sudo ./cache-images
```

Finally, these are ip table rules that are needed for heat and local docker registry to work.  Dockery regsitry is using port 8080 in this case.
```
sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8000,8003,8004 --jump ACCEPT
sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8080 --jump ACCEPT
```
