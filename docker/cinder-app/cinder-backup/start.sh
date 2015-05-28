#!/bin/bash

set -e

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-cinder.sh

check_required_vars BACKUP_DRIVER BACKUP_MANAGER BACKUP_API_CLASS \
                    BACKUP_NAME_TEMPLATE

# volume backup configuration
crudini --set /etc/cinder/cinder.conf \
        DEFAULT \
        backup_driver \
        "${BACKUP_DRIVER}"
crudini --set /etc/cinder/cinder.conf \
        DEFAULT \
        backup_topic \
        "cinder-backup"
crudini --set /etc/cinder/cinder.conf \
        DEFAULT \
        backup_manager \
        "${BACKUP_MANAGER}"
crudini --set /etc/cinder/cinder.conf \
        DEFAULT \
        backup_api_class \
        "${BACKUP_API_CLASS}"
crudini --set /etc/cinder/cinder.conf \
        DEFAULT \
        backup_name_template \
        "${BACKUP_NAME_TEMPLATE}"

echo "Starting cinder-backup"
exec /usr/bin/cinder-backup --config-file /etc/cinder/cinder.conf
