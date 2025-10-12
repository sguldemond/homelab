# Proxmox

Setting up both machines as a Proxmox VE node.
Splitting both machines into two, creating 4 VMSs:
- 1x Control Node
- 2x Worker Nodes
- 1x Virtual Router

On each host machine a bridge is setup for the local VMs to connect to.