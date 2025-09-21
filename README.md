# 🏠 Homelab: Mac minis + K3s + Debian

A lightweight Kubernetes homelab setup running on 2x repurposed Apple Mac mini hardware.
This homelab setup provides a cost-effective way to freely explore Kubernetes features.

## Projects

- [Portal](projects/portal/README.md)
    - Simple WebUI with read access to cluster
    - SvelteKit + Kubernetes RBAC
- [Cloudflare Tunnel](projects/cloudflare-tunnel/README.md)
    - Tunnels through to my K3s server
    - Forwards traffic to Service, currently used for the Portal
- [Observability](projects/observability/README.md)
    - Getting insight into pod logs a la Azure Application Insight
    - Fluent Bit + Loki + Grafana
- [Container Registry](projects/container-registry/README.md)
    - Self hosted container registry


## Hardware

[<img src="./images/macminis.jpg" width="400" />](./images/macminis.jpg)

### Control Node

| Component | Specification |
|-----------|---------------|
| **Machine** | Apple Mac mini Mid 2014 (Model A1347) |
| **RAM** | 4 GB |
| **Storage** | Internal 500GB HDD |

### Worker Node

| Component | Specification |
|-----------|---------------|
| **Machine** | Apple Mac mini Late 2012 (Model A1347) |
| **RAM** | 2 GB + 4 GB |
| **Storage** | Internal 500GB HDD |

Both machines run K3s on headless Debian 13.

## Networking

Both machines are connected to the same network via Ethernet.
The router is providing static IP addresses to the machines.
The router also provides DNS resolution for the machines.

Both machines are reachable via SSH, enabling kubectl access from another machine on the same LAN.
