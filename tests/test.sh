export K8S_NODE_NAME="${1}"
export CF_AUTH_EMAIL="${2}"
export CF_AUTH_KEY="${3}"
export CF_ZONE_NAME="odata.org.il"
export CF_RECORD_NAME="dnstest.odata.org.il"
export CF_ZONE_UPDATE_DATA_TEMPLATE='{"type":"A","name":"dnstest","content":"{{NODE_IP}}","ttl":120,"proxied":false}'
export K8S_NODE_ADDRESS_CONDITION="address['type'] == 'InternalIP'"
./entrypoint.sh
