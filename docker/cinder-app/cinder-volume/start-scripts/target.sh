#!/bin/bash

set -e

DESC="target framework daemon"
NAME=targetctl
DAEMON=/usr/bin/${NAME}

# Start tgtd first.
echo "Starting targetctl $DESC"
exec $DAEMON
