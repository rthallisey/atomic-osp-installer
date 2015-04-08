# Building and image with the tripleo baremetal flavor

In order to intregrate with tripleo, we need to have a baremetal machine successfully spawning.  There are a series of steps highlighted below on how to setup to boot your baremetal machine using the rhel-atomic-cloud image.

http://download.eng.rdu2.redhat.com/rel-eng/Atomic/7/images/7.1/cdn/rhel-atomic-host-image/FILES/

You need the qcow2, initrd, and vmlinuz images.

./tripleo-incubator/scripts/load_image rhel-atomic...

Make sure that the baremetal flavor and the properties for the image set the correct ramdisk and kernel image.

eg:

$ glance image-update d47f5292-8dc4-4b4f-9b7e-a86e60c42eb9 --property ramdisk_id=1a3baadd-51a0-4d0f-baca-92a3885132cd

$ nova flavor-key baremetal set baremetal:deploy_ramdisk_id=1a3baadd-51a0-4d0f-baca-92a3885132cd

$ nova flavor-show baremetal

$ nova image-show rhel-atomic...

You have to rebuild the initrd to add a hack to get around the ip arguments that ironic passes:

```
[root@openstack 00fix-ironic-ip]# pwd
/usr/lib/dracut/modules.d/00fix-ironic-ip
[root@openstack 00fix-ironic-ip]# ls
deploy-cmdline.sh  module-setup.sh
[root@openstack 00fix-ironic-ip]# cat deploy-cmdline.sh
#!/bin/bash

# Dracut doesn't correctly parse the ip argument passed to us.
# Override /proc/cmdline to rewrite it in a way dracut can grok.
sed 's/\(ip=\S\+\)/\1:::off/' /proc/cmdline > /run/cmdline
mount -n --bind -o ro /run/cmdline /proc/cmdline
# Force Dracut to re-read the cmdline args
CMDLINE=
[root@openstack 00fix-ironic-ip]# cat module-setup.sh
#!/bin/bash

check() {
   return 0
}
depends() {
   return 0
}
install() {
   inst_hook cmdline 80 "$moddir/deploy-cmdline.sh"
}
[root@openstack 00fix-ironic-ip]# dracut --add-drivers ext4 /tmp/initrd-v5
[root@openstack 00fix-ironic-ip]#

```

Upload new initrd and make sure the flavor and image point to the right one.

We seem to need to add:

pxe_append_params="root=/dev/sda2"

to ironic.conf.

Restart services:

```
sudo systemctl restart ironic-conductor
sudo systemctl restart nova-compute
```
