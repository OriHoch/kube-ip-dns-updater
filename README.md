# kube-ip-dns-updater

Run it as an initContainer on a Kubernetes pod using hostPort and it will update the node's IP in Cloudflare or Route53 DNS.

## Quickstart

### Create secret

**Cloudflare**

```
kubectl create secret generic kube-ip-dns-updater-test \
    --from-literal=CF_ZONE_NAME=example.com \
    --from-literal=CF_RECORD_NAME=test.example.com \
    --from-literal=CF_AUTH_EMAIL=<CLOUDFLARE_AUTHENTICATION_EMAIL> \
    --from-literal=CF_AUTH_KEY=<CLOUDFLARE_AUTHENTICATION_SECRET_KEY> \
    --from-literal=CF_ZONE_UPDATE_DATA_TEMPLATE='{"type":"A","name":"test","content":"{{NODE_IP}}","ttl":120,"proxied":false}'
```

**Route53**

```
kubectl create secret generic kube-ip-dns-updater-test \
    --from-literal=AWS_ZONE_NAME=example.com \
    --from-literal=AWS_ZONE_UPDATE_DATA_TEMPLATE='{"Name": "test.example.com.","Type": "A","TTL": 120,"ResourceRecords": [{"Value": "{{NODE_IP}}"}]}' \
    --from-literal=AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID=> \
    --from-literal=AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
```

### Create service account and cluster role binding

Modify `rbac.yaml` - set the names and namespace

apply it: `kubectl apply -f my-rbac.yaml`

### Modify your pod/deployment

Add a `serviceAccountName` referring to the service account name created in the rbac

Add the kube-ip-dns-updated initContainer - see an example in `tests/nginx-deployment.yaml`

Ensure it uses the relevant kube-ip-dns-updater secret created earlier

### Configure nodeSelector

It's recommended to limit pods to schedule only on the relevant node to prevent frequent DNS updates

Update the pod spec with the relevant nodeName:

```
    spec:
      nodeSelector:
        kubernetes.io/hostname: <nodeName>
      containers:
```

When the node is not available, remove or replace the nodeSelector to schedule on a new node and DNS will be updated automatically.

To get the name of the node the pod is currently scheduled on you can use this snippet

```
kubectl get pod -l app=nginx -o yaml | grep 'nodeName:'
```

### Setting up the firewall for hostPorts

Common use-case for kube-ip-dns-updater is to use hostPort to expose pods without load balancer.

In this case you need to open the relevant port in the Google Compute instance firewall.

Google Kubernetes engine assigns the label `goog-gke-node` to all nodes in the cluster which you can use to set the firewall:

```
gcloud compute firewall-rules create k8s-host-port-5432 --allow=tcp:5432 --target-tags=goog-gke-node
```
