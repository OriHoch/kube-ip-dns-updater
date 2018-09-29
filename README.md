# kube-ip-dns-updater

Run it as an initContainer on a Kubernetes pod using hostPort and it will update the node's IP in Cloudflare's DNS.

## Quickstart

Create the required secret, for example:

```
kubectl create secret generic kube-ip-dns-updater-test \
    --from-literal=CF_ZONE_NAME=example.com \
    --from-literal=CF_RECORD_NAME=test.example.com \
    --from-literal=CF_AUTH_EMAIL=<CLOUDFLARE_AUTHENTICATION_EMAIL> \
    --from-literal=CF_AUTH_KEY=<CLOUDFLARE_AUTHENTICATION_SECRET_KEY> \
    --from-literal=CF_ZONE_UPDATE_DATA_TEMPLATE='{"type":"A","name":"test","content":"{{NODE_IP}}","ttl":120,"proxied":false}'
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
