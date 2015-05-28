FROM %%KOLLA_NAMESPACE%%/%%KOLLA_PREFIX%%cinder-base
MAINTAINER Kolla Project (https://launchpad.net/kolla)

ADD ./start.sh /start.sh
ADD ./check.sh /check.sh

CMD ["/start.sh"]
