#!/bin/bash

set -e

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-cinder.sh

: ${VOLUME_API_LISTEN:="0.0.0.0"}
: ${VOLUME_GROUP:="cinder-volumes57"}
: ${LVM_LO_VOLUME_SIZE:="4G"}

check_required_vars VOLUME_API_LISTEN ISCSI_HELPER ISCSI_IP_ADDRESS

# At some point this needs to be based on an environment variable
. /opt/kolla/cinder/volume-group-create.sh

cfg=/etc/cinder/cinder.conf

# Logging
crudini --set $cfg \
        DEFAULT \
        log_file \
        "${CINDER_VOLUME_LOG_FILE}"

# IP address on which OpenStack Volume API listens
crudini --set $cfg \
        DEFAULT \
        osapi_volume_listen \
        "${VOLUME_API_LISTEN}"

# The IP address that the iSCSI daemon is listening on
crudini --set $cfg \
        DEFAULT \
        iscsi_ip_address \
        "${ISCSI_IP_ADDRESS}"

# Set to false when using loopback devices (testing)
crudini --set $cfg \
        DEFAULT \
        secure_delete \
        "false"

crudini --set $cfg \
        DEFAULT \
        enabled_backends \
        "lvm57"

crudini --set $cfg \
        lvm57 \
        iscsi_helper \
        "${ISCSI_HELPER}"

crudini --set $cfg \
        lvm57 \
        volume_group \
        "${VOLUME_GROUP}"

crudini --set $cfg \
        lvm57 \
        volume_driver \
        "cinder.volume.drivers.lvm.LVMISCSIDriver"

crudini --set $cfg \
        lvm57 \
        iscsi_ip_address \
        "${ISCSI_IP_ADDRESS}"

crudini --set $cfg \
        lvm57 \
        volume_backend_name \
        "LVM_iSCSI57"

sed -i 's/udev_sync = 1/udev_sync = 0/' /etc/lvm/lvm.conf
sed -i 's/udev_rules = 1/udev_rules = 0/' /etc/lvm/lvm.conf
sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf

echo "Starting cinder-volume"
exec /usr/bin/cinder-volume --config-file /etc/cinder/cinder.conf
