FROM fedora
MAINTAINER “Rabi Mishra” <ramishra@redhat.com>
ENV container docker
RUN yum -y update; yum clean all

RUN yum -y install os-collect-config os-apply-config os-refresh-config \
  dib-utils python-yaml python-docker-py

ADD ./scripts/55-heat-config \
 /opt/stack/os-config-refresh/configure.d/

ADD ./scripts/50-heat-config-docker-compose \
 /opt/stack/os-config-refresh/configure.d/

ADD ./scripts/* \
  /var/lib/heat-config/hooks/

ADD ./scripts/heat-config-notify \
   /usr/bin/heat-config-notify

ADD ./scripts/configure_docker_agents.sh /tmp/
RUN chmod 700 /tmp/configure_docker_agents.sh ; \
  /tmp/configure_docker_agents.sh

#create volumes to share the host directories
VOLUME [ "/var/lib/cloud"]
VOLUME [ "/var/lib/heat-cfntools" ]

#set DOCKER_HOST environment variable that docker-compose would use
ENV DOCKER_HOST unix:///var/run/docker.sock

CMD /usr/bin/os-collect-config
