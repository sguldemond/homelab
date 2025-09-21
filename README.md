# 🏠 Homelab

A lightweight Kubernetes homelab setup running on 2x repurposed Apple Mac mini hardware.

This homelab setup provides a cost-effective way to learn Kubernetes and run personal services while maintaining security through Tailscale VPN.


## 📋 Hardware Specifications

## Control Node

| Component | Specification |
|-----------|---------------|
| **Machine** | Apple Mac mini Mid 2014 (Model A1347) |
| **RAM** | 4 GB |
| **Storage** | Internal 500GB HDD |

## Worker Node

| Component | Specification |
|-----------|---------------|
| **Machine** | Apple Mac mini Late 2012 (Model A1347) |
| **RAM** | 2 GB + 4 GB |
| **Storage** | Internal 500GB HDD |


## 🌐 Network Configuration

| Setting | Value |
|---------|-------|
| **Static IP** | 192.168.1.100 |
| **SSH Access** | ✅ Enabled and working |
| **Network Interface** | Ethernet |

## 🔧 Initial Setup Process

### Disk Preparation
- Booted into macOS Recovery to attempt mounting CoreStorage volume
- Created two disk images:
  - Unlocked CoreStorage volume image
  - Full encrypted disk image
- Backed both images up to the Maxtor drive

### OS Installation
- Booted into Ubuntu 24.04 Live USB
- Used `ddrescue` to clone the full disk to an image (minimal read errors)
- Performed disk zeroing (overwrite with zeros) to mark/remap bad sectors

### Debian Installation ✅
- Successfully installed Debian (headless) on Mac mini
- Configured static IP: `192.168.1.100`
- SSH access established and working
- System ready for next phase of setup

## 🖥️ Planned Software Stack

### Operating System
- **OS**: Debian (headless, no desktop environment)

### Container Orchestration
- **Platform**: K3s (lightweight Kubernetes)

### Remote Access
- **VPN**: Tailscale (no port forwarding needed)

## 🚀 Cluster Usage

### Primary Services
- Run services like an Nginx-based blog
- Experiment with Gateway API for ingress routing

## 🌐 Networking Configuration

### Local Access
- `kubectl` from another machine on the same LAN

### Remote Access
- Tailscale to securely connect over the internet without exposing ports
- Tailscale IP in kubeconfig for remote `kubectl` access

## 🔒 Security Measures

- SSH:
    - Restricted root login: `PermitRootLogin no`
