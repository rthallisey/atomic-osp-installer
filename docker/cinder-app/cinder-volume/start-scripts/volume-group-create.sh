#!/bin/bash

set -e

backing_file=/opt/data/cinder_volume

size=${LVM_LO_VOLUME_SIZE}
volume_group=${VOLUME_GROUP}

# Set up the volume group.
if ! vgs $volume_group; then
    # Create a backing file to hold our volumes.
    [[ -f $backing_file ]] || truncate -s $size $backing_file
    vg_dev=`losetup -f --show $backing_file`
    # Only create volume group if it doesn't already exist
    if ! vgs $volume_group; then
        vgcreate $volume_group $vg_dev
    fi
fi

# Remove iscsi targets
cinder-rtstool get-targets | xargs -rn 1 cinder-rtstool delete

