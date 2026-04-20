# v2 — OVN-kubernetes EgressService + MetalLB L2

Extends v1 with OVN-kubernetes EgressService so pods use the LoadBalancer IP
(`192.168.2.120`) as their source IP for outbound traffic instead of the pod IP.

`externalTrafficPolicy: Local` works here but is redundant.
The combination of EgressService and OVN's egress handling resolves the TCP issue seen in v1.

## Components
- **kong/**: go-echo deployment, LoadBalancer service, and EgressService
- **metallb/**: dedicated single-IP pool (`192.168.2.120/32`, autoAssign disabled)
  and L2Advertisement scoped to the node OVN selects via the egress label

## Key relationships
- Service and EgressService are linked by matching name+namespace
- OVN labels the selected node with `egress-service.k8s.ovn.org/default-go-echo-service`
- L2Advertisement uses that label so MetalLB announces the VIP from the same node
