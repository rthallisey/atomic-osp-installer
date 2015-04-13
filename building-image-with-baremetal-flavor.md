# Building and image with the tripleo baremetal flavor

In order to intregrate with tripleo, we need to have a baremetal machine
successfully spawning.  There are a series of steps highlighted below on how to
setup to boot your baremetal machine using the rhel-atomic-cloud image.

http://download.eng.rdu2.redhat.com/rel-eng/Atomic/7/images/7.1/cdn/rhel-atomic-host-image/FILES/

Make a new baremetal flavor that includes no swap or ephemeral disk:
```
nova flavor-create baremetal_fulldisk auto 4096 10 1
```

Set the right ramdisk and kernel images for setting up the image:
```
$ nova flavor-key baremetal_fulldisk set baremetal:deploy_kernel_id=f38d630b-0d00-4cae-83cf-4e824ef07625
$ nova flavor-key baremetal_fulldisk set baremetal:deploy_ramdisk_id=f38d630b-0d00-4cae-83cf-4e824ef07625
```

There seems to be a bug still in the ironic driver that looks to see if swap or
ephemeral is > 0 and errors if it is.  I had to hack this to get around it.
Can't look now I'll update this later.

Restart services:
```
sudo systemctl restart ironic-conductor
sudo systemctl restart nova-compute
```
