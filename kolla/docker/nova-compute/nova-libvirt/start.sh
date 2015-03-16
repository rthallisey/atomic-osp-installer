#!/bin/sh

# If libvirt is not installed on the host permissions need to be set
chmod 666 /dev/kvm

echo "Starting libvirtd."
exec /usr/sbin/libvirtd
