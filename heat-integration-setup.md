# Heat integration setup
In order to use heat to deploy openstack, there are a few things required.

Create a local docker registry to cache the images. Choose the port this will use. In the example we use 8080 instead of 5000 (default) because keystone will be using 5000.
```
sudo yum install docker-registry
sudo systemctl start docker-registry  
```

nova instances requires these rules:
```
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
```

Ip table rules that are needed for heat and local docker registry to work.  Dockery regsitry is using port 8080.
```
sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8000,8003,8004 --jump ACCEPT
sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8080 --jump ACCEPT
```

For a virt setup you need to allow nested virtualization.
```
sudo rmmod kvm-intel
sudo sh -c "echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf"
sudo modprobe kvm-intel
```

Also, in order for nova to put /dev/kvm on the rhel-atomic host you need to edit the nova config.
```
cpu mode=host-passthrough
```
Restart nova and check your atomic host to see that /dev/kvm exists.