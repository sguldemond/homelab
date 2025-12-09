# Proxmox

Setting up both machines as a Proxmox VE node.
Splitting both machines into two, creating 4 VMSs:
- 1x Control Node
- 2x Worker Nodes
- 1x Virtual Router

On each host machine a bridge is setup for the local VMs to connect to.

```
           (LAN Switch / Router)
                     │
           ┌─────────┴─────────┐
           │   Physical LAN    │
           └─────────┬─────────┘
                     │
              NIC (enp3s0) (no IP)
                     │
        ┌────────────┴────────────┐
        │      br0 (bridge)       │
        ├────────────┬────────────┤
        │            │            │
Host (192.168.1.100) |  VM1 (192.168.1.111)
                     |
           VM2 (192.168.1.112)
```