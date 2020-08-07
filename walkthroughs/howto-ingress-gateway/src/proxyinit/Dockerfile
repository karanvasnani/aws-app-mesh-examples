FROM amazonlinux:latest

RUN yum install -y iptables iputils iproute nc

COPY sidecar-proxy-route-manager.sh /opt/amazon/bin/sidecar-proxy-route-manager.sh

ENV ROOT /opt/amazon/

WORKDIR /opt/amazon

ENTRYPOINT /opt/amazon/bin/sidecar-proxy-route-manager.sh
