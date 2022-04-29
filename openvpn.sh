#!/bin/bash

readonly SCRIPT_PATH="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
readonly CONFIG_DIR="/vpn/configs"

readonly IP_REGEX='(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
readonly IP_ONLY_REGEX='^'${IP_REGEX}'$'
readonly CIDR_ONLY_REGEX='^('${IP_REGEX}'\/([0-9]|1[0-9]|2[0-9]|3[0-2]))$'
readonly HOSTNAME_REGEX='((([a-zA-Z0-9]|[a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9\-]*[A-Za-z0-9]))'
readonly HOSTS_ENTRY_REGEX='^'${IP_REGEX}'\s+'${HOSTNAME_REGEX}'(\s+'${HOSTNAME_REGEX}')*\s*''$'

readonly PROTO="${PROTOCOL:=TCP}"
readonly ENC_STR="${STRENGTH:=STRONG}"
readonly DNS=${CUSTOM_DNS:=10.0.0.242}

validate_env() {
    if [[ -z "${USERNAME}" ]]; then
        echo "USERNAME not specified.";
        exit 1;
    fi

    if [[ -z "${PASSWORD}" ]]; then
        echo "PASSWORD not specified.";
        exit 1;
    fi

    if [[ -z "${REGION}" ]]; then
        echo "REGION not specified.";
        exit 1;
    fi

    if ! [[ "${PROTO}" =~ ^(UDP|TCP)$ ]]; then
        echo "Invalid PROTOCOL value."
        exit 1;
    fi

    if ! [[ "${ENC_STR}" =~ ^(NORMAL|STRONG)$ ]]; then
        echo "Invalid STRENGTH value."
        exit 1;
    fi

    if ! [[ "${SUBNET}" =~ ${CIDR_REGEX} ]]; then
        echo "Invalid subnet.";
        exit 1;
    fi

    if ! [[ "${DNS}" =~ ${IP_ONLY_REGEX} ]]; then
        echo "Invalid DNS server IP address";
        exit 1;
    fi

    if ! [[ -z "${HOSTS}" ]]; then
        local entries;
        readarray -d ":" -t entries <<< "${HOSTS}";

        local entry;
        for entry in "${entries[@]}"; do
            if ! [[ "${entry}" =~ ${HOSTS_ENTRY_REGEX} ]]; then
                echo "Invalid hosts file entry.";
                exit 1;
            fi
        done
    fi 
}

retrieve_configs() {
    if ! [[ -d "${CONFIG_DIR}" ]]; then
        mkdir -p "${CONFIG_DIR}";
    fi

    cd "${CONFIG_DIR}";

    local modifier="";
    if [[ ${ENC_STR} == "STRONG" ]]; then
       modifier="-strong";
    fi
    if [[ ${PROTO} == "TCP" ]]; then
       modifier="${modifier}-tcp";
    fi
    
    wget -O config.zip "https://www.privateinternetaccess.com/openvpn/openvpn${modifier}.zip";

    if [ $? -ne 0 ]; then
        echo "Failed to retrieve configuration files.";
        exit 1;
    fi

    unzip config.zip;
    rm config.zip;

    cd "${SCRIPT_PATH}";
}

update_configs() {
    local file
    for file in ${CONFIG_DIR}/*.ovpn; do
        echo "pull-filter ignore route-ipv6" >> "${file}";
        echo "pull-filter ignore ifconfig-ipv6" >> "${file}";
        echo "dhcp-option DNS ${DNS}" >> "${file}";
        echo "up /etc/openvpn/update-resolv-conf" >> "${file}";
        echo "down /etc/openvpn/update-resolv-conf" >> "${file}";
    done
}

install_rules() {
    local port;
    if [[ ${PROTO} == "UDP" ]] && [[ ${ENC_STR} == "NORMAL" ]]; then
       port="1998";
    fi
    if [[ ${PROTO} == "UDP" ]] && [[ ${ENC_STR} == "STRONG" ]]; then
       port="1197";
    fi
    if [[ ${PROTO} == "TCP" ]] && [[ ${ENC_STR} == "NORMAL" ]]; then
       port="502";
    fi
    if [[ ${PROTO} == "TCP" ]] && [[ ${ENC_STR} == "STRONG" ]]; then
       port="501";
    fi

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT;
    iptables -A OUTPUT -o lo -j ACCEPT;
    if [[ -n ${SUBNET} ]]; then
        iptables -A INPUT -d ${SUBNET} -j ACCEPT;
        iptables -A OUTPUT -d ${SUBNET} -j ACCEPT;
    fi
    iptables -A OUTPUT -d ${DNS} -p udp --dport 53 -j ACCEPT;
    iptables -A OUTPUT -d ${DNS} -p tcp --dport 53 -j ACCEPT;
    iptables -A OUTPUT -p tcp -m tcp --dport ${port} -j ACCEPT;
    iptables -A OUTPUT -o tun0 -j ACCEPT;
    iptables -A OUTPUT -p udp --dport 53 -m owner --gid-owner vpn -j ACCEPT;
    iptables -A OUTPUT -p tcp --dport 53 -m owner --gid-owner vpn -j ACCEPT;
}

install_policies() {
    iptables -P INPUT DROP;
    iptables -P OUTPUT DROP;
    iptables -P FORWARD DROP;
}

firewall() {
    if ! [[ -x `command -v iptables` ]]; then
        echo "iptables not installed";
        exit 1;
    fi

    install_rules;
    install_policies;
}

install_route() {
    if [[ -n ${SUBNET} ]]; then
        local gateway=$(ip route | grep 'default' | awk '{print $3}');
        ip route add ${SUBNET} via ${gateway} dev eth0;
    fi
}

install_local_resolve() {
    if [[ -z "${HOSTS}" ]]; then
        return;
    fi
    
    local entries;
    readarray -d ":" -t entries <<< "${HOSTS}";

    local entry;
    for entry in "${entries[@]}"; do
        echo "${entry}" >> /etc/hosts
    done
}

routes() {
    install_route;
    install_local_resolve;
}

start() {
    local region_file=$(echo "${REGION}".ovpn | awk '{print tolower($0)}');

    if ! [[ -f ${CONFIG_DIR}/"${region_file}" ]]; then
        echo "REGION not found.";
        exit 1;
    fi

    echo ${USERNAME} >> auth.txt
    echo ${PASSWORD} >> auth.txt
    
    exec sg vpn -c 'openvpn --script-security 2 --config '${CONFIG_DIR}/"${region_file}"' --auth-user-pass auth.txt';
}

main() {
    validate_env;
    retrieve_configs;
    update_configs;
    firewall;
    routes;
    start;
}

main;
