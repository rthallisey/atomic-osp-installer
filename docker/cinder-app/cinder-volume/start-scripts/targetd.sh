#!/bin/bash

set -e

DESC="targetd framework daemon"
NAME=targetd
DAEMON=/usr/bin/${NAME}

# Start tgtd first.
echo "Starting targetd $DESC"
exec $DAEMON
