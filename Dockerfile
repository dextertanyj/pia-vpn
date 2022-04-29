FROM ubuntu:20.04
LABEL maintainer="dev@dextertanyj.com"

RUN apt-get update && \
    apt-get install -y bash curl iptables openresolv openvpn unzip wget

RUN mkdir -p /vpn

COPY openvpn.sh /vpn/
RUN chmod +x /vpn/openvpn.sh

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl --fail https://api.ipify.org || exit 1

ENTRYPOINT [ "/vpn/openvpn.sh" ]
