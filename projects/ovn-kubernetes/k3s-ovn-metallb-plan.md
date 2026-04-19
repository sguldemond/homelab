# Plan: k3s Cluster Setup with OVN-kubernetes and MetalLB

## Context
mm1 (Mac Mini 1) is running Fedora CoreOS with k3s installed, but currently using the default Flannel CNI. The goal is to replace Flannel with OVN-kubernetes to experiment with advanced networking (EgressService, egress bugs), join mbp as a worker node, and deploy MetalLB for load balancing. The cluster has no production workloads yet, making this a good time to swap the CNI.

**Nodes:**
- mm1: `192.168.2.60` — control plane, Tailscale `100.69.168.103`
- mbp: worker, IP via DHCP

**Key files:**
- `infra/coreos/mm1/k3s-config.yaml` — k3s config (deployed to `/etc/rancher/k3s/config.yaml`)
- `infra/coreos/mm1/macmini1-butane.yaml` — SOPS-encrypted Butane config
- `infra/k3s/` — MetalLB, registry, older k3s configs

---

## Phase 1: Reconfigure k3s on mm1 without Flannel

**1.1 Update k3s-config.yaml in repo**

Add to `infra/coreos/mm1/k3s-config.yaml`:
```yaml
flannel-backend: none
disable-network-policy: true
disable:
  - servicelb
```

**1.2 Apply config on mm1 and restart k3s**

SSH into mm1:
```bash
sudo tee /etc/rancher/k3s/config.yaml <<EOF
flannel-backend: none
disable-network-policy: true
disable:
  - servicelb

tls-san:
  - "macmini1"
  - "macmini1.tail9271d2.ts.net"
  - "100.69.168.103"
  - "192.168.2.60"
EOF

sudo systemctl stop k3s
sudo rm -rf /var/lib/cni /etc/cni /var/lib/rancher/k3s/agent/etc/cni
sudo systemctl start k3s
```

Node will show `NotReady` — expected until OVN-kubernetes is deployed.

---

## Phase 2: Deploy OVN-kubernetes

Using the official Helm chart (dist/yaml are generated from Jinja2 templates, not pre-built).

**2.1 Install via Helm on mm1:**
```bash
git clone https://github.com/ovn-kubernetes/ovn-kubernetes.git /tmp/ovn-kubernetes
cd /tmp/ovn-kubernetes/helm/ovn-kubernetes

helm install ovn-kubernetes . \
  -f values-single-node-zone.yaml \
  --set k8sAPIServer="https://192.168.2.60:6443" \
  --set global.image.repository=ghcr.io/ovn-kubernetes/ovn-kubernetes/ovn-kube-ubuntu \
  --set global.image.tag=master
```

> Note: OVN-kubernetes images include OVS — no host-level OVS install needed on CoreOS.

**2.2 Verify node becomes Ready:**
```bash
kubectl get nodes -w
kubectl get pods -n ovn-kubernetes
```

---

## Phase 3: Add mbp as Worker Node

**3.1 Get cluster token from mm1:**
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

**3.2 SSH into mbp and install k3s agent:**
```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.2.60:6443 \
  K3S_TOKEN=<token-from-mm1> \
  sh -
```

**3.3 Verify mbp joins cluster:**
```bash
# On mm1
kubectl get nodes
```

---

## Phase 4: Deploy MetalLB

Apply manifests directly:
```bash
kubectl apply -f infra/k3s/ip-address-pool.yaml
kubectl apply -f infra/k3s/l2-advertisement.yaml
```

MetalLB pool: `192.168.2.110–192.168.2.200` (Layer 2 mode)

---

## Verification

```bash
# All nodes Ready
kubectl get nodes

# OVN pods healthy
kubectl get pods -n ovn-kubernetes

# MetalLB pods healthy
kubectl get pods -n metallb-system

# Test LoadBalancer: deploy a simple service and check it gets an external IP
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=LoadBalancer --port=80
kubectl get svc nginx  # should show 192.168.2.110-range IP
```
