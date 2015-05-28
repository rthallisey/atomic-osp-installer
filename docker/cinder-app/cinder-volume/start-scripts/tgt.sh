#!/bin/bash

set -e

DESC="target framework daemon"
NAME=tgtd
DAEMON=/usr/sbin/${NAME}

TGTD_CONFIG=/etc/tgt/targets.conf

echo "include /var/lib/cinder/volumes/*" >> $TGTD_CONFIG

echo "Starting tgtd $DESC"
/usr/sbin/tgtd -f &>/dev/null
echo "Set to offline"
tgtadm --op update --mode sys --name State -v offline
echo "Set tgt config"
tgt-admin -e -c $TGTD_CONFIG
echo "Set to ready"
tgtadm --op update --mode sys --name State -v ready
