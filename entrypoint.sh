#!/usr/bin/env bash

if [ "${OVERRIDE_NODE_IP}" != "" ]; then
    NODE_IP="${OVERRIDE_NODE_IP}"
else
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
fi
if [ "${NODE_IP}" == "" ]; then
    echo no external IP for pod
    exit 0
else
    if [ "${CF_ZONE_ID}" != "" ]; then
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
    else
        echo Updating external IP $NODE_IP in Amazone Route53
        HOSTED_ZONE_ID=`aws route53 list-hosted-zones | \
                            python -c "import sys,json;\
                                       print([z['Id'] for z in json.load(sys.stdin)['HostedZones'] \
                                             if z['Name'] == '${AWS_ZONE_NAME}.'][0].split('/')[2])"` && ! [ -z "${HOSTED_ZONE_ID}" ]
        [ "$?" != "0" ] && echo Failed to get zone id for zone name ${AWS_ZONE_NAME} && exit 1
        echo zone id = ${HOSTED_ZONE_ID}
        TEMPLATE_TEMPFILE=`mktemp`
        echo '{
            "Comment": "kube-ip-dns-updater ${AWS_ZONE_NAME} ${HOSTED_ZONE_ID}",
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": '"${AWS_ZONE_UPDATE_DATA_TEMPLATE}"'
                }
            ]
        }' > $TEMPLATE_TEMPFILE
        TEMPFILE=`mktemp`
        export NODE_IP
        ./templater.sh $TEMPLATE_TEMPFILE > $TEMPFILE
        CHANGE_ID=`aws route53 change-resource-record-sets \
                       --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://${TEMPFILE} | \
                           python -c "import sys,json;\
                                      print(json.load(sys.stdin)['ChangeInfo']['Id'].split('/')[2])"` && ! [ -z "${CHANGE_ID}" ]
        [ "$?" != "0" ] && echo Failed to get change id && exit 1
        if [ "${AWS_WAIT_FOR_CHANGE}" == "" ]; then
            echo route53 change id ${CHANGE_ID} submitted
        else
            echo waiting for route53 change id ${CHANGE_ID} to complete
            while sleep 1; do
                echo .
                [ "$(aws route53 get-change --id "${CHANGE_ID}" \
                     | python -c "import sys,json;print(json.load(sys.stdin)['ChangeInfo']['Status'])")" != "PENDING" ] &&\
                aws route53 get-change --id "${CHANGE_ID}" && break
            done
        fi
        echo Update complete
        exit 0

    fi
fi
