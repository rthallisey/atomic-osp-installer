#!/bin/bash

set -e

DESC="lvm metadata service"
NAME=lvmetad
DAEMON=/usr/sbin/${NAME}

echo "Starting $DESC"
exec $DAEMON -f
