# v1 — Basic OVN-kubernetes + MetalLB L2

Basic LoadBalancer setup using MetalLB in L2 mode with a shared IP pool.
No EgressService — pods use their own pod IP for outbound traffic.

`externalTrafficPolicy: Local` was found to break TCP with OVN-kubernetes.
Switched to `Cluster` as workaround.

## Components
- **kong/**: go-echo deployment and LoadBalancer service (TCP+UDP on port 2701)
- **metallb/**: IPAddressPool (`192.168.2.110-192.168.2.200`) and L2Advertisement
