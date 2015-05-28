#!/bin/bash

. /opt/kolla/kolla-common.sh
. /opt/kolla/config-ceilometer.sh


check_required_vars KEYSTONE_ADMIN_TOKEN RABBITMQ_SERVICE_HOST RABBIT_PASSWORD

fail_unless_os_service_running keystone

# Nova conf settings
crudini --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
crudini --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
crudini --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
crudini --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
crudini --set /etc/nova/nova.conf DEFAULT notification_driver ceilometer.compute.nova_notifier

#ceilometer settings
cfg=/etc/ceilometer/ceilometer.conf
crudini --set $cfg publisher_rpc metering_secret ${KEYSTONE_ADMIN_TOKEN}
crudini --set $cfg rabbit_host ${RABBITMQ_SERVICE_HOST}
crudini --set $cfg rabbit_password ${RABBIT_PASSWORD}


exec /usr/bin/ceilometer-agent-compute
