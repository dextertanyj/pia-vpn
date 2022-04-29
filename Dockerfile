FROM ubuntu:20.04
LABEL maintainer="dev@dextertanyj.com"

RUN apt-get update && apt-get install bash curl iptables openvpn unzip wget -y

RUN mkdir -p /vpn
RUN addgroup vpn

COPY openvpn.sh /vpn/
RUN chmod +x /vpn/openvpn.sh

CMD [ "/vpn/openvpn.sh" ]
