#!/usr/bin/env bash

set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

METADATA_BASE_URL="http://169.254.169.254/latest/meta-data"
CONSUL_SERVER_COUNT_MIN=${CONSUL_SERVER_COUNT_MIN:-0}
THIS_PRIVATE_IP=$(curl --silent --location ${METADATA_BASE_URL}/local-ipv4)
THIS_INSTANCE_REGION=$(curl --silent --location ${METADATA_BASE_URL}/placement/availability-zone | sed 's/.$//')

consul_config_dir='/etc/consul'
consul_data_dir='/var/lib/consul'
consul_ui_dir='/usr/share/consul'

addresses=$("${BASE_DIR}/getASGInstanceAddresses.sh")

while [ "$(echo "$addresses" | sed 's/\s/\n/g' | wc -l)" -lt "${CONSUL_SERVER_COUNT_MIN}" ]; do
    sleep 5
    addresses=$("${BASE_DIR}/getASGInstanceAddresses.sh)")
done

if [ "$CONSUL_SERVER_COUNT_MIN" -eq "0" ]; then
    address_count=$(echo "$addresses" | sed 's/\s/\n/g' | wc -l)
    CONSUL_SERVER_COUNT_MIN=$address_count
fi

bootstrapper_ip="$(echo "$addresses" | sed 's/\s/\n/g' | head -1)"
this_is_bootstrapper="false"
if [ "$THIS_PRIVATE_IP" == "$bootstrapper_ip" ]; then
    this_is_bootstrapper="true"
fi

joined=""
for ip in $addresses; do
    if [ "$ip" != "$THIS_PRIVATE_IP" ]; then
        if [ -n "$joined" ]; then
            joined="$joined ,"
        fi
        joined="$joined \"$ip\""
    fi
done

join_or_bootstrap=""
if [ "true" = "$this_is_bootstrapper" ]; then
    join_or_bootstrap="\"bootstrap_expect\": $CONSUL_SERVER_COUNT_MIN,"
else
    join_or_bootstrap="\"start_join\": [$joined],"
fi

cat <<EOF > "$consul_config_dir/consul.json"
{
    $join_or_bootstrap
    "addresses" : {
        "http": "$THIS_PRIVATE_IP"
    },
    "bind_addr": "$THIS_PRIVATE_IP",
    "node_name": "$THIS_PRIVATE_IP",
    "log_level": "INFO",
    "server": true,
    "rejoin_after_leave": true,
    "enable_syslog": true,
    "data_dir": "$consul_data_dir",
    "ui_dir": "$consul_ui_dir",
    "datacenter": "${CONSUL_DATACENTER_NAME:-$THIS_INSTANCE_REGION}"
}
EOF

