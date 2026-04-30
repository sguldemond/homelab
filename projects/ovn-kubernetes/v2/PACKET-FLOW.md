# OVN-K + MetalLB L2 — Packet Flow Reference

This document describes how packets travel through the k3s / OVN-Kubernetes /
MetalLB L2 stack for a service with `externalTrafficPolicy: Local` and an
`EgressService` with `sourceIPBy: LoadBalancerIP`, with OVN configured in
`gatewayMode: local`.

Scope: **MetalLB L2 mode** only. For the BGP variant (v3) the differences are
noted at the end.

---

## Cluster topology

```
Nodes
  mm1  — 192.168.2.60   (control plane, no pod endpoint)
  mbp  — 192.168.2.11   (worker, runs the pod)

VIP    — 192.168.2.120/32  (MetalLB L2, announced from mbp)
Pod    — 10.42.X.Y:8000    (CIDR 10.42.0.0/16, /24 per node)
SvcCIDR— 10.43.0.0/16
Join   — 100.64.0.0/16     (OVN join switch subnet)

OVN bridge topology on mbp
  brens9       physical NIC bridge (OVN external bridge, on LAN)
  br-int       OVS integration bridge
  patch-br-int-to-brens9_mbp   patch port between them (OFPort 4)

br-int metadata tags
  0x5 = ext switch (brens9 side)
  0x4 = GR_mbp (Gateway Router)
  0x3 = node switch (pod side)
```

### OVN logical topology

```
                     LAN (192.168.2.0/24)
                          │
                     [ext_mbp]          ← OVN external switch
                          │
                       [GR_mbp]         ← per-node Gateway Router
                          │
                    [join switch]        ← 100.64.0.0/16
                          │
               [ovn_cluster_router]     ← cluster-wide router
                          │
                   [node switch mbp]    ← 10.42.X.0/24
                          │
                     [pod LSP]          ← pod veth
```

---

## Settings and what they create

### `type: LoadBalancer` + MetalLB L2Advertisement

| Object | Created by | Effect |
|---|---|---|
| `IPAddressPool` | MetalLB CR | Allocates 192.168.2.120 to the Service |
| `L2Advertisement` (interfaces: brens9) | MetalLB CR | Constrains ARP announcements to brens9 |
| ARP reply for 192.168.2.120 | MetalLB speaker on mbp | LAN learns 192.168.2.120 → brens9 MAC |
| `svc.status.loadBalancer.ingress[0].ip` | MetalLB controller | `192.168.2.120` |

MetalLB automatically restricts L2 announcements to nodes that have a local
endpoint when `externalTrafficPolicy: Local` — no manual `nodeSelector` on
the L2Advertisement is required.

---

### `externalTrafficPolicy: Local`

OVN-K creates **per-node, per-protocol LoadBalancers on the Gateway Router**
(not cluster-wide LBs). Source: `lb_config.go` `buildPerNodeLBs()`.

| Node | Endpoint? | LB target | LB options |
|---|---|---|---|
| mbp | yes | `10.42.X.Y:8000` | `skip_snat=true` |
| mm1 | no | *(empty)* | `reject=true` |

`skip_snat=true` means the GR does **not** replace the client source IP with
the router's IP. The pod sees the real client IP.

`reject=true` on mm1 means any packet to the VIP arriving at mm1 gets an
immediate RST — there is no silent black-hole.

---

### `gatewayMode: local`

Each node gets its own Gateway Router (GR_mbp, GR_mm1). The node's physical
NIC is bridged into OVN's external bridge (`brens9`), so inbound packets enter
the OVN pipeline **directly** — they do not pass through the host IP stack
first (contrast: `shared` mode, where traffic enters via `breth0` and the host
routes it into OVN via a masquerade IP).

Consequence for ETP=Local: the DNAT lives entirely inside OVN's GR pipeline.
No host iptables DNAT rule is needed for inbound traffic.

---

### `EgressService sourceIPBy: LoadBalancerIP`

OVN-K creates:

1. **One LogicalRouterPolicy per pod IP on `ovn_cluster_router`:**
   - Priority: 101 (`EgressSVCReroutePriority`)
   - Match: `ip4.src == <pod-ip>`
   - Action: `reroute` → mbp's management port IP (on the join subnet)
   - Effect: all pod egress is forced through mbp regardless of the default
     route — so outbound packets leave from the same node that owns the VIP.

2. **Node label on mbp:**
   `egress-service.k8s.ovn.org/default-socat-echo-service`

3. **iptables SNAT rule in `OVN-KUBE-EGRESS-SVC` on mbp:**
   `10.42.X.Y → 192.168.2.120` (POSTROUTING, applied after the rerouted packet
   exits ovn-k8s-mp0 into the host network stack)

Source: `egressservice_zone_service.go` `createOrUpdateLogicalRouterPoliciesOps()`.

---

## Inbound packet flow (client → VIP → pod)

```
CLIENT (192.168.2.Z:SPORT)
  │
  │  1. ARP: "Who has 192.168.2.120?"
  │     MetalLB speaker on mbp replies: "I have it (brens9 MAC)"
  │
  ▼
LAN → mbp brens9
  │  src=192.168.2.Z:SPORT   dst=192.168.2.120:8000
  │
  │  2. Frame arrives on brens9, enters br-int via patch port (OFPort 4)
  │     metadata = 0x5  (ext switch context)
  │
  ▼
br-int — ext switch → GR_mbp transition
  │     metadata = 0x4  (GR_mbp context)
  │
  │  3. Table 15 — conntrack zone 11 (REG11)
  │     ct(commit, zone=11)   new TCP flow tracked, DNAT zone
  │
  │  4. Table 18 — LB group dispatch
  │     group:14 → nat(dst=10.42.X.Y:8000)   [DNAT applied]
  │     ct_mark bit set (identifies LB flow)
  │
  │     src=192.168.2.Z:SPORT   dst=10.42.X.Y:8000   ← after DNAT
  │
  ▼
br-int — node switch (metadata=0x3)
  │
  ▼
Pod veth (eth0)
  │  Pod receives:  src=192.168.2.Z   dst=10.42.X.Y
  │                  (real client IP — skip_snat preserved it)
  ▼
socat listener — echoes data back
```

**IP transformation summary (inbound):**

| Hop | src IP | dst IP |
|---|---|---|
| Client → brens9 | 192.168.2.Z | 192.168.2.120 |
| After GR_mbp DNAT | 192.168.2.Z | 10.42.X.Y |
| Pod sees | 192.168.2.Z | 10.42.X.Y |

---

## Outbound / reply flow (pod → VIP → client)

```
Pod veth
  │  src=10.42.X.Y:8000   dst=192.168.2.Z:SPORT
  │
  ▼
br-int — node switch → ovn_cluster_router
  │
  │  5. Table 26 — EgressService reroute (priority 101 LRP)
  │     match:  ip4.src == 10.42.X.Y
  │     action: reroute → mbp management port (join subnet IP)
  │     (forces packet to exit via mbp, which owns the VIP)
  │
  ▼
ovn-k8s-mp0  (mbp management port, enters host network stack)
  │
  │  6. iptables POSTROUTING — OVN-KUBE-EGRESS-SVC chain
  │     SNAT: src=10.42.X.Y → 192.168.2.120
  │
  │     src=192.168.2.120:8000   dst=192.168.2.Z:SPORT   ← after SNAT
  │
  ▼
mbp brens9 → LAN
  │
  ▼
CLIENT
  │  Receives:  src=192.168.2.120   dst=192.168.2.Z
  │             (reply source = VIP — symmetry preserved)
```

**IP transformation summary (outbound):**

| Hop | src IP | dst IP |
|---|---|---|
| Pod sends | 10.42.X.Y | 192.168.2.Z |
| After EgressService SNAT | 192.168.2.120 | 192.168.2.Z |
| Client sees | 192.168.2.120 | 192.168.2.Z |

---

## Conntrack zones

| Zone | Bridge | Tracks |
|---|---|---|
| 11 (REG11) | br-int | Inbound DNAT on GR_mbp — also used for **reverse-DNAT** on return traffic entering from the client side |
| 13 (REG13) | br-int | SNAT zone on GR — idle when `skip_snat=true` (ETP=Local) |
| brens9 | brens9 | External CT; ensures ARP-announced packets use the correct egress port |

The zone 11 entry is what allows the reply path (client → 192.168.2.120) to
be un-DNAT'd back to 10.42.X.Y without seeing the LB group again. If this
entry is missing or in the wrong state, SYN-ACK reaches the pod but the
client's subsequent ACK gets silently dropped.

---

## Effect of removing each setting

| Without | Symptom |
|---|---|
| **EgressService** | Pod replies with `src=10.42.X.Y`; client received reply from an IP it never sent to — stateful TCP breaks. v1 workaround was `externalTrafficPolicy: Cluster` (hides the asymmetry at the cost of source IP). |
| **ETP=Local** | Cluster-wide LB used; GR SNATs client IP to router IP; pod loses client IP; traffic can reach mm1 and get hair-pinned. |
| **gatewayMode=local** | Inbound goes through host IP stack + iptables DNAT (masquerade IP 169.254.169.3); brens9 is no longer the OVN external bridge entry point; EgressService return path changes. |

---

## Non-endpoint node behaviour (mm1)

When a client connects to 192.168.2.120 and the ARP reply comes from mm1
(e.g., if MetalLB momentarily announces from mm1, or a stale ARP entry exists):

- mm1's GR LB has `reject=true` (no local endpoint)
- OVN sends RST immediately
- Client sees `Connection refused` rather than a timeout hang

This is intentional: `reject=true` is set by OVN-K precisely when ETP=Local
is active and no endpoint exists on the node, to fail fast rather than silently
drop packets.

---

## Validation commands

Set the OVN pod variable once at the top of your session:

```bash
OVN_MBP=$(kubectl get pods -n ovn-kubernetes -o wide | awk '/mbp/{print $1}')
POD=$(kubectl get pods -l app=socat-echo -o name | head -1)
```

### L0 — ARP / VIP ownership

```bash
# Confirm MetalLB L2 speaker owns the VIP on mbp (check reply MAC = brens9 MAC)
arping -c 3 192.168.2.120

# MetalLB speaker logs — look for "announcing" and "192.168.2.120"
kubectl logs -n metallb-system -l component=speaker --tail=40 | grep -i 192.168.2.120
```

### L1 — Kubernetes objects

```bash
# Service has a LoadBalancer IP
kubectl get svc socat-echo-service

# EgressService is accepted (status.conditions should show Ready)
kubectl get egressservice socat-echo-service -o yaml

# mbp is labelled as the EgressService node
kubectl get node mbp --show-labels | tr ',' '\n' | grep egress-service
```

### L2 — OVN NB objects

```bash
# List LBs for the VIP — expect one per protocol, attached to GR only (ETP=Local)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-nbctl lb-list | grep 192.168.2.120

# LB details: skip_snat, reject, targets
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-nbctl find load_balancer | grep -B2 -A10 192.168.2.120

# EgressService LRPs on cluster router (priority 101, action=reroute)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-nbctl lr-policy-list ovn_cluster_router | grep -E '101|reroute'
```

### L3 — OVS flows

```bash
# DNAT flows on GR_mbp (metadata=0x4, tables 15 and 18)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-ofctl dump-flows br-int | grep 'metadata=0x4' | grep -E 'nat|ct'

# LB group definition — shows actual pod IP targets
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-ofctl dump-groups br-int | grep -A5 "group_id=14"

# EgressService reroute flows (table 26)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-ofctl dump-flows br-int table=26

# Full flow dump with packet counters (run before+after nc to see which flows hit)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-ofctl dump-flows br-int
```

### L4 — Conntrack

```bash
# OVS datapath conntrack entries for VIP or pod IP (run while nc is in flight)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-appctl dpctl/dump-conntrack | grep -E '192\.168\.2\.120|10\.42\.'

# Host conntrack on mbp (zone 0 — EgressService SNAT entries)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  conntrack -L 2>/dev/null | grep -E '192\.168\.2\.120|10\.42\.'
```

### L5 — iptables SNAT (EgressService)

```bash
# SNAT rule added by EgressService controller: pod IP → VIP
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  iptables -t nat -L OVN-KUBE-EGRESS-SVC -n -v
# Expected output: SNAT rule with to:192.168.2.120 matching src 10.42.X.Y
```

### L6 — Live three-layer packet capture

Run each capture in its own terminal, then trigger from a fourth:

```bash
# Terminal 1: pod NIC — dst should be pod IP (post-DNAT), src = real client IP
kubectl exec $POD -c tcp-echo -- tcpdump -nni eth0 'tcp port 8000' -c 20

# Terminal 2: brens9 — inbound dst=192.168.2.120, outbound src=192.168.2.120
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  tcpdump -nni brens9 'tcp port 8000' -c 20

# Terminal 3: symbolic OVS trace (replace placeholders with real MACs/IPs)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-appctl ofproto/trace br-int \
  "in_port=4,tcp,dl_src=<CLIENT_MAC>,dl_dst=<BRENS9_MAC>,\
nw_src=<CLIENT_IP>,nw_dst=192.168.2.120,tcp_src=54321,tcp_dst=8000"

# Terminal 4: trigger
nc -zv 192.168.2.120 8000
```

### L7 — OVN logical trace (symbolic packet walk)

Fetch real values first:

```bash
# brens9 MAC
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovn-controller -- \
  ovs-vsctl list interface brens9 | grep mac_in_use

# Pod LSP name
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-nbctl show | grep -A2 "$(kubectl get pod -l app=socat-echo -o jsonpath='{.items[0].status.podIP}')"
```

```bash
# Inbound: external client → VIP → pod  (--ct new = new connection)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-trace --ct new mbp \
  'inport == "ext_mbp" \
   && eth.src == aa:bb:cc:dd:ee:ff \
   && eth.dst == <BRENS9_MAC> \
   && ip4.src == 192.168.2.11 && ip4.dst == 192.168.2.120 \
   && ip.ttl == 64 && tcp && tcp.src == 54321 && tcp.dst == 8000'

# Outbound reply: pod → cluster router → EgressService reroute  (--ct est = established)
kubectl exec -n ovn-kubernetes $OVN_MBP -c ovnkube-controller -- \
  ovn-trace --ct est mbp \
  'inport == "<POD_LSP>" \
   && eth.src == <POD_MAC> && eth.dst == <GW_MAC> \
   && ip4.src == <POD_IP> && ip4.dst == 192.168.2.11 \
   && ip.ttl == 64 && tcp && tcp.src == 8000 && tcp.dst == 54321'
```

---

## Source references

| Behaviour | File | Location |
|---|---|---|
| Per-node GR LBs for ETP=Local | `go-controller/pkg/ovn/controller/services/lb_config.go` | `buildPerNodeLBs()` ~line 600; `noSNATRouterRules` condition line 700; `SkipSNAT=true` line 739 |
| EgressService LRP creation | `go-controller/pkg/ovn/controller/egressservice/egressservice_zone_service.go` | `createOrUpdateLogicalRouterPoliciesOps()` line 237; priority 101 |
| gatewayMode setting | `projects/ovn-kubernetes/values.yaml` | `global.gatewayMode: local` (changed from `shared` — shared mode broke EgressService egress flow) |

---

## BGP mode differences (v3)

In v3 the MetalLB L2Advertisement is replaced by a BGPAdvertisement + BGPPeer.
The OVN side is identical — GR_mbp, EgressService LRPs, skip_snat, the
iptables SNAT rule all work the same. The only change is how the VIP route
reaches the router:

| | L2 (v2) | BGP (v3) |
|---|---|---|
| VIP announcement | ARP reply from brens9 MAC | BGP route 192.168.2.130/32 via 192.168.2.11 |
| Node selection | MetalLB respects ETP=Local automatically via ARP | MetalLB speaker only advertises routes for IPs on its own node |
| VyOS config | ARP proxy / static route not needed | eBGP peer (AS 64513 ↔ 64512) |
| L2Advertisement CR | required (interface pin) | not used |
