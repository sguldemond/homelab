# 🏠 Homelab: Mac minis + K3s + Debian

A lightweight Kubernetes homelab setup running on 2x repurposed Apple Mac mini hardware.
This homelab setup provides a cost-effective way to freely explore Kubernetes features.

## Projects

- [Container Registry](projects/container-registry/README.md): Self hosted container registry.
- [Observability](projects/observability/README.md): Getting insight into pod logs a la Azure Application Insight.
- [Portal](projects/portal/README.md): Simple WebUI with read access to cluster.

## Hardware

### Control Node

[<img src="./images/macminis.jpg" width="400" />](./images/macminis.jpg)

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
