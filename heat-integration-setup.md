# Heat integration setup
In order to use heat to deploy openstack, there are a few things required.

Create a local docker registry to cache the images. Choose the port this will use. In the example we use 8080 instead of 5000 (default) because keystone will be using 5000.
     sudo yum install docker-registry
     sudo systemctl start docker-registry  

nova instances requires these rules:
     nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
     nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0

Ip table rules that are needed for heat and local docker registry to work.  Dockery regsitry is using port 8080.
     sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8000,8003,8004 --jump ACCEPT
     sudo iptables -A IN_FedoraServer_allow -p tcp -m multiport --dports 8080 --jump ACCEPT