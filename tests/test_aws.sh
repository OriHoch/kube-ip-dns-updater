export OVERRIDE_NODE_IP="${1}"
export AWS_ACCESS_KEY_ID="${2}"
export AWS_SECRET_ACCESS_KEY="${3}"
export AWS_ZONE_NAME="oknesset.org"
export AWS_ZONE_UPDATE_DATA_TEMPLATE='{"Name": "dnstest2.oknesset.org.","Type": "A","TTL": 120,"ResourceRecords": [{"Value": "{{NODE_IP}}"}]}'
./entrypoint.sh
