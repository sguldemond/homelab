# Load Balancing

K3s comes with a built-in ServiceLB, but I want to use MetalLB.
Starting of with Layer 2 mode which used the ARP protocol.
After that, moving on to BGP mode.

Installed MetalLB using Manifests: https://metallb.io/installation/#installation-by-manifest
For setting up BGP mode I could use the Kustomize installation: https://metallb.io/installation/#installation-with-kustomize

