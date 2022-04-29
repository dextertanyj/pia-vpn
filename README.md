# Private Internet Access

A Private Internet Access (PIA) container with built in killswitch.

## Usage

Here are some example snippets to help you get started creating a container.

### Docker Compose

```yaml
version: "3.1"
services:
  pia-vpn:
    image: dextertanyj/pia-vpn
    container_name: pia-vpn
    environment:
      - USERNAME=username
      - PASSWORD=password
      - REGION=region
      - CUSTOM_DNS=1.1.1.1 #optional
      - PROTOCOL=TCP #optional
      - STRENGTH=STRONG #optional
      - SUBNET=192.168.1.0/24 #optional
      - HOSTS='192.168.1.1 hostname.example.com' #optional
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=1
    restart: unless-stopped
```

### Docker CLI

```bash
docker run -d \
  --name pia-vpn \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --sysctl=net.ipv6.conf.all.disable_ipv6=1 \
  -e USERNAME=username \
  -e PASSWORD=password \
  -e REGION=region \
  -e CUSTOM_DNS=1.1.1.1 \ #optional
  -e PROTOCOL=TCP \ #optional
  -e STRENGTH=STRONG \ #optional
  -e SUBNET=192.168.1.0/24 \ #optional
  -e HOSTS='192.168.1.1 hostname.example.com' \ #optional
  --restart unless-stopped \
  dextertanyj/pia-vpn
```

## Parameters

| Parameter                                    | Function                                           |
| -------------------------------------------- | -------------------------------------------------- |
| `-e USERNAME=username`                       | PIA account username                               |
| `-e PASSWORD=password`                       | PIA account password                               |
| `-e REGION=region`                           | PIA region                                         |
| `-e CUSTOM_DNS=1.1.1.1`                      | Custom DNS server                                  |
| `-e PROTOCOL=TCP`                            | Network protocol (`TCP` or `UDP`)                  |
| `-e STRENGTH=STRONG`                         | OpenVPN encryption strength (`NORMAL` or `STRONG`) |
| `-e SUBNET=192.168.1.0/24`                   | Local subnet to route through default gateway      |
| `-e HOSTS='192.168.1.1 hostname.example.com` | A colon separated list of hosts file entries       |

## Routing Other Containers Through the PIA VPN

Route the traffic of other containers through the VPN using the `--net=container:pia-vpn` option during their creation.
