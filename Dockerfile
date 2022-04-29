FROM alpine:latest
LABEL maintainer="dev@dextertanyj.com"

RUN apk update && apk add bash curl shadow openvpn

RUN mkdir -p /vpn
RUN addgroup vpn

COPY openvpn.sh /vpn/
RUN chmod +x /vpn/openvpn.sh

CMD [ "/vpn/openvpn.sh" ]
