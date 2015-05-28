#!/bin/bash

set -e

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-cinder.sh

if ! [ "$CINDER_DB_PASSWORD" ]; then
  CINDER_DB_PASSWORD=$(openssl rand -hex 15)
  export CINDER_DB_PASSWORD
fi

## Check DB connectivity and required variables
echo "Checking connectivity to the DB"
fail_unless_db

echo "Checking for required variables"
check_required_vars MARIADB_SERVICE_HOST DB_ROOT_PASSWORD \
                    CINDER_DB_NAME CINDER_DB_USER CINDER_DB_PASSWORD

cfg=/etc/cinder/cinder.conf

# Setup the cinder database
echo "Setting up the cinder database"
mysql -h ${MARIADB_SERVICE_HOST} -u root \
        -p${DB_ROOT_PASSWORD} mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${CINDER_DB_NAME};
GRANT ALL PRIVILEGES ON ${CINDER_DB_NAME}.* TO
        '${CINDER_DB_USER}'@'%' IDENTIFIED BY '${CINDER_DB_PASSWORD}'
EOF

# Initialize the Keystone DB
if [ "${INIT_DB}" == "true" ] ; then
  echo "Initializing the Cinder database"
  /bin/sh -c "cinder-manage db sync" cinder
fi

# Logging
crudini --set $cfg \
        DEFAULT \
        log_file \
        "${CINDER_SCHEDULER_LOG_FILE}"

# Start cinder-scheduler
echo "Starting cinder-scheduler"
exec /usr/bin/cinder-scheduler --config-file $cfg
