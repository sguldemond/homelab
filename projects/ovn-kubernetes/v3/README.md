# v3 — MetalLB BGP Mode with EgressService

Replaces L2/ARP advertisement from v1/v2 with eBGP peering between MetalLB
speakers and VyOS. BGP naturally handles node selection — no manual interface
pinning or per-service nodeSelector coupling needed.

## ASN Design (eBGP)
- VyOS: AS 64513
- k8s nodes (mm1 + mbp): AS 64512

VyOS uses dynamic neighbors so any node in 192.168.2.0/24 can peer
automatically — no VyOS changes needed when adding new nodes.

## VyOS config (one-time)

Static neighbors — dynamic neighbor listen range (`set protocols bgp listen range`)
did not work on VyOS despite being documented; bgpd started but reported no BGP
instance. Static neighbors did work:
```
configure
set protocols bgp system-as '64513'
set protocols bgp neighbor 192.168.2.60 remote-as '64512'
set protocols bgp neighbor 192.168.2.60 description 'mm1'
set protocols bgp neighbor 192.168.2.60 address-family ipv4-unicast
set protocols bgp neighbor 192.168.2.11 remote-as '64512'
set protocols bgp neighbor 192.168.2.11 description 'mbp'
set protocols bgp neighbor 192.168.2.11 address-family ipv4-unicast
commit
save
exit
```

## Components

### One-time infrastructure (generic — works for all services)
- **metallb/bgp-peer.yaml** — MetalLB speakers peer with VyOS (192.168.2.1)
- **metallb/bgp-ip-pool.yaml** — shared IP range 192.168.2.130-140, autoAssign disabled
- **metallb/bgp-advertisement.yaml** — advertises bgp-pool, no nodeSelector (BGP handles it)

### Per service
- **kong/go-echo-service.yaml** — annotated with `bgp-pool`, `externalTrafficPolicy: Local`
- **kong/go-echo-egress-service.yaml** — OVN EgressService, pods use LB IP as source

## nodeSelector in EgressService

No `nodeSelector` is set in the EgressService. With `externalTrafficPolicy: Local`:
- MetalLB via BGP only advertises the VIP from nodes that have a local pod endpoint
- OVN EgressService without a `nodeSelector` also picks from nodes with matching pods

Both naturally converge on the same node, and follow pods automatically as they
move or scale across workers — no manual node pinning needed.

## Apply order
```bash
kubectl apply -f v3/metallb/bgp-peer.yaml
kubectl apply -f v3/metallb/bgp-ip-pool.yaml
kubectl apply -f v3/metallb/bgp-advertisement.yaml
kubectl apply -f v3/kong/go-echo-service.yaml
kubectl apply -f v3/kong/go-echo-egress-service.yaml
```
