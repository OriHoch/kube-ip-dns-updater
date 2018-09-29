#!/usr/bin/env bash

if [ "${K8S_NODE_ADDRESS_CONDITION}" == "" ]; then
    export K8S_NODE_ADDRESS_CONDITION="address['type'] == 'ExternalIP'"
fi

! NODE_IP=`kubectl get node "${K8S_NODE_NAME}" -o json | \
              python -c "import json, sys;\
                         addresses = [address['address'] for address \
                                      in json.load(sys.stdin)['status']['addresses'] \
                                      if ${K8S_NODE_ADDRESS_CONDITION}]; \
                         print(addresses[0] if len(addresses) > 0 else '')"` \
    && echo Failed to get IP for node $K8S_NODE_NAME && exit 1
if [ "${NODE_IP}" == "" ]; then
    echo no external IP for pod
    exit 0
else
    echo Updating external IP $NODE_IP in Cloudflare
    ! CF_ZONE_ID=`curl -X GET "https://api.cloudflare.com/client/v4/zones" \
                       -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                       -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                       -H "Content-Type: application/json" | \
                          python -c "import json, sys; \
                                     zones = [zone['id'] for zone in json.load(sys.stdin)['result'] \
                                     if zone['name'] == '${CF_ZONE_NAME}']; \
                                     print(zones[0] if len(zones) > 0 else '')"` \
    && echo Failed to get zone id for zone name ${CF_ZONE_NAME} && exit 1
    ! CF_RECORD_ID=`curl -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
                         -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                         -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                         -H "Content-Type: application/json" | \
                            python -c "import json, sys; \
                                       records = [record['id'] for record in json.load(sys.stdin)['result'] \
                                       if record['name'] == '${CF_RECORD_NAME}']; \
                                       print(records[0] if len(records) > 0 else '')"` \
    && echo Failed to get record id in zone name ${CF_ZONE_NAME} record name ${CF_RECORD_NAME} && exit 1
    echo Updating record name ${CF_RECORD_NAME} in zone name ${CF_ZONE_NAME}
    echo zone id = ${CF_ZONE_ID}  record id = ${CF_RECORD_ID}
    TEMPFILE=`mktemp`
    echo "${CF_ZONE_UPDATE_DATA_TEMPLATE}" > $TEMPFILE
    export NODE_IP
    UPDATE_SUCCESS=`curl -X PUT \
                         "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" \
                         -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                         -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                         -H "Content-Type: application/json" \
                         --data "$(./templater.sh $TEMPFILE)" | \
                            python -c "import json,sys; \
                                       print(json.load(sys.stdin)['success'])"`
    if [ "${UPDATE_SUCCESS}" == "True" ]; then
        echo Updated DNS record ${CF_RECORD_NAME} with node IP ${NODE_IP}
        exit 0
    else
        echo Failed to update record
        exit 1
    fi
fi
