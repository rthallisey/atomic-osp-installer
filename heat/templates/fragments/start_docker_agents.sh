#!/bin/bash
set -eux

# heat-docker-agents service
cat <<EOF > /etc/systemd/system/heat-docker-agents.service

[Unit]
Description=Heat Docker Agent Container
After=docker.service
Requires=docker.service

[Service]
User=root
Restart=on-failure
ExecStartPre=-/usr/bin/docker kill heat-agents
ExecStartPre=-/usr/bin/docker rm heat-agents
ExecStartPre=/usr/bin/docker pull $agent_image
ExecStart=/usr/bin/docker run --name heat-agents --privileged --net=host -v /etc:/host/etc -v /usr/bin/atomic:/usr/bin/atomic -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/cloud:/var/lib/cloud -v /var/lib/heat-cfntools:/var/lib/heat-cfntools $agent_image
ExecStop=/usr/bin/docker stop heat-agents

[Install]
WantedBy=multi-user.target

EOF

# update docker for local insecure registry(optional)
# Note: This is different for different docker versions
# For older docker versions < 1.4.x use commented line
echo "OPTIONS='--insecure-registry $docker_registry --selinux-enabled'" >> /etc/sysconfig/docker
echo "ADD_REGISTRY='--add-registry $docker_registry'" >> /etc/sysconfig/docker

/sbin/setenforce 0

# enable and start docker
/usr/bin/systemctl enable docker.service
/usr/bin/systemctl restart --no-block docker.service

# enable and start heat-docker-agents
chmod 0640 /etc/systemd/system/heat-docker-agents.service
/usr/bin/systemctl enable heat-docker-agents.service
/usr/bin/systemctl start --no-block heat-docker-agents.service
