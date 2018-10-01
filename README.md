# kube-ip-dns-updater

Run it as an initContainer on a Kubernetes pod using hostPort and it will update the node's IP in Cloudflare or Route53 DNS.

## Quickstart

Create the required secret -

### Cloudflare

```
kubectl create secret generic kube-ip-dns-updater-test \
    --from-literal=CF_ZONE_NAME=example.com \
    --from-literal=CF_RECORD_NAME=test.example.com \
    --from-literal=CF_AUTH_EMAIL=<CLOUDFLARE_AUTHENTICATION_EMAIL> \
    --from-literal=CF_AUTH_KEY=<CLOUDFLARE_AUTHENTICATION_SECRET_KEY> \
    --from-literal=CF_ZONE_UPDATE_DATA_TEMPLATE='{"type":"A","name":"test","content":"{{NODE_IP}}","ttl":120,"proxied":false}'
```

### Route53

```
kubectl create secret generic kube-ip-dns-updater-test \
    --from-literal=AWS_ZONE_NAME=example.com \
    --from-literal=AWS_ZONE_UPDATE_DATA_TEMPLATE='{"Name": "test.example.com.","Type": "A","TTL": 120,"ResourceRecords": [{"Value": "{{NODE_IP}}"}]}' \
    --from-literal=AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID=> \
    --from-literal=AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
```

Add an initContainer to relevant pod spec, see `tests/nginx-deployment.yaml`

The kubernetes service account assigned to the pod needs to have relevant permissions to read node details.

The following command gives cluster admin permissions to the default service account:

```
kubectl create rolebinding kube-ip-dns-updated-rolebinding \
               --clusterrole=admin --user=system:serviceaccount:my-namespace:default --namespace=my-namespace
```

Apply the deployment, e.g. `kubectl apply -f tests/nginx-deployment.yaml`

The pod will update it's own DNS on initialization.

It's recommended to limit this pod to scheduling only on this node from now on, check the node name:

```
kubectl get pod -l app=nginx -o yaml | grep 'nodeName:'
```

Update the pod spec with the nodeName the pod is currently scheduled on:

```
    spec:
      nodeSelector:
        kubernetes.io/hostname: <nodeName>
      containers:
```

When the node is not available, remove or replace the nodeSelector to schedule on a new node and DNS will be updated automatically.
