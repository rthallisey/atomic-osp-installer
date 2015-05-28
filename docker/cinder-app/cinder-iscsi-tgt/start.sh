#!/bin/bash

set -e

DESC="target framework daemon"
NAME=tgtd
DAEMON=/usr/sbin/${NAME}

TGTD_CONFIG=/etc/tgt/targets.conf

echo "include /etc/cinder/volumes/*" >> $TGTD_CONFIG

# Start tgtd first.
echo "Starting tgtd $DESC"
exec $DAEMON -f

# Put tgtd into "offline" state until all the targets are configured.
# We don't want initiators to (re)connect and fail the connection
# if it's not ready.
#echo "Putting tgt in offline state"
#tgtadm --op update --mode sys --name State -v offline

# Configure the targets.
#echo "Configuring targets"
#tgt-admin -e -c $TGTD_CONFIG

# Put tgtd into "ready" state.
#echo "Putting tgtd in ready state"
#tgtadm --op update --mode sys --name State -v ready

## Start tgtd
#echo "Final tgtd start"
#exec /usr/sbin/tgtd -f
