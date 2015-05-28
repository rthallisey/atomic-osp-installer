FROM %%KOLLA_NAMESPACE%%/%%KOLLA_PREFIX%%cinder-base
MAINTAINER Kolla Project (https://launchpad.net/kolla)

# Install supervisor
RUN easy_install supervisor

# Install supervisor-stdout
RUN pip install supervisor-stdout

# Install required packages
RUN yum install -y lvm2 scsi-target-utils && yum clean all

# Create cinder directory
RUN mkdir -p /opt/kolla/cinder

# Add start scripts
ADD start-scripts/tgt.sh /opt/kolla/cinder/
ADD start-scripts/volume.sh /opt/kolla/cinder/
ADD start-scripts/volume-group-create.sh /opt/kolla/cinder/

# Configure supervisord
RUN mkdir -p /var/log/supervisor/
ADD supervisord.conf /etc/

# Start supervisor
CMD ["/usr/bin/supervisord"]
