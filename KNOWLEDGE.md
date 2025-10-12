# Knowledge 🧠

How iptables fit in with the ClusterIP Service.

## Bridging vs. Routing vs. NAT

| Mode | Layer | What it does | Typical use |
|------|-------|--------------|-------------|
| Bridge | 2 (Ethernet) | Forwards frames between interfaces | VMs in same LAN |
| Router | 3 (IP) | Moves packets between networks/subnets | Connecting LANs |
| NAT | 3+4 | Rewrites IPs to share one address | Internet access sharing |

## Subnet mask

The subnet mask tells the system which portion of the IP address refers to the network and which portion refers to the host.

/24 → 24 bits of the address (out of 32) are for the network

The remaining 8 bits are for hosts

| CIDR | Mask | Network Range | Host Range | # Hosts |
|------|-------|--------------|-------------| ------- |
| /24 | 255.255.255.0 | 192.168.1.0 | 192.168.1.1–192.168.1.254 | 254 |
| /25 | 255.255.255.128 | 192.168.1.0 | 192.168.1.1–192.168.1.126 | 126 |
| /16 | 255.255.0.0 | 192.168.0.0 | 192.168.0.1–192.168.255.254 | 65,534 |
