#!/bin/bash

set -e

TGTD_CONFIG=/etc/tgt/targets.conf

# Put tgtd into "offline" state until all the targets are configured.
# We don't want initiators to (re)connect and fail the connection
# if it's not ready.
echo "Putting tgt in offline state"
tgtadm --op update --mode sys --name State -v offline

# Configure the targets.
echo "Configuring targets"
tgt-admin -e -c $TGTD_CONFIG

# Put tgtd into "ready" state.
echo "Putting tgtd in ready state"
tgtadm --op update --mode sys --name State -v ready
