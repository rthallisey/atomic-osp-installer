# Building and image with the tripleo baremetal flavor

In order to intregrate with tripleo, we need to have a baremetal machine
successfully spawning.  There are a series of steps highlighted below on how to
setup to boot your baremetal machine using the rhel-atomic-cloud image.

http://download.devel.redhat.com/rel-eng/Atomic-7.1-images/rhel-atomic-cloud-7.1-9.x86_64.qcow2

Make a new baremetal flavor that includes no swap or ephemeral disk:
```
nova flavor-create baremetal_fulldisk auto 3072 10 1
```

Set the right ramdisk and kernel images for setting up the image:
```
    nova flavor-key baremetal_fulldisk set baremetal:deploy_kernel_id=<baremetal kernel>
    nova flavor-key baremetal_fulldisk set baremetal:deploy_ramdisk_id=<baremetal ramdisk>
    nova flavor-key baremetal_fulldisk set cpu_arch=amd64
```

There seems to be a bug in ironic as installed on the seed vm so you need to
edit (on the seed VM):

iscsi_deploy.py

in two locations and change:

/opt/stack/venvs/openstack/lib/python2.7/site-packages/ironic/drivers/modules/iscsi_deploy.py
/opt/stack/venvs/nova/lib/python2.7/site-packages/ironic/drivers/modules/iscsi_deploy.py

```
    i_info['swap_mb'] = info.get('swap_mb', 0)
    i_info['ephemeral_gb'] = info.get('ephemeral_gb', 0)
    err_msg_invalid = _("Cannot validate parameter for iSCSI deploy. "
                        "Invalid parameter %(param)s. Reason: %(reason)s")
```

to

```
    i_info['swap_mb'] = 0
    i_info['ephemeral_gb'] = 0
    err_msg_invalid = _("Cannot validate parameter for iSCSI deploy. "
                        "Invalid parameter %(param)s. Reason: %(reason)s")
```

Restart services:

```
sudo systemctl restart ironic-conductor
sudo systemctl restart nova-compute
```

Add chain.c32 to tftpboot so that it can use it for pxe booting (again on the
seed VM):

```
cp /boot/extlinux/chain.c32 /tftpboot
```
