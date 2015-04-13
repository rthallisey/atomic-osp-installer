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
$ nova flavor-key baremetal_fulldisk set baremetal:deploy_kernel_id=<baremetal kernel>
$ nova flavor-key baremetal_fulldisk set baremetal:deploy_ramdisk_id=<baremetal ramdisk>
```

There seems to be a bug in ironic as installed on the seed vm so you need to edit:

iscsi_deploy.py

in two locations (use find) and change:

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
