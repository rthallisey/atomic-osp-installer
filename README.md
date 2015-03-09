# atomic-osp-installer
Install Openstack using Kolla containers.  Openstack containers are spun up by a bash script using individual 'docker run' commands with the appropriate enviornment variables necessary for them to work.

The current services being built by this install script:
services:
* Rabbitmq
* Mariadb
* Keystone
* Glance

Setup
===========
Run the install script.
```
$ sudo ./install.sh
```
Docker will go out and pull the latest kolla containers and start them up.  After the containers are cached, the next time you stand up openstack it should only take about a minute.

Usage
===========
Most of the enviorment variables being passed into the containers are hard coded and can be changed.  Your credentials are being added into openrc on the host and are based on these enviroment varibales.
```
$ source openrc
```
Now you're free to run openstack on your host!
```
$ keystone user-list
```
```
$ glance image-list
```

NOTE: The install script pulls from imain's and rthallisey's docker repos for Nova and Glace images.  The Kolla Glance containers will not function properly until the race condition between keystone and glance-api is fixed. https://bugs.launchpad.net/kolla/+bug/1429104

Debug
===========
If any command hangs or doesn't work, check to see that the service in question has its container running.
```
$ sudo docker ps
```
Check the logs of any container in question.  Keep in mind, if a container exited or failed it will only be listed with a 'sudo docker ps -a'.
```
$ sudo docker logs <container id>
```
