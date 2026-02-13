# Journal

---

Added the Gitea Helm chart to the cluster.
Pods fail to start, cannot pull images from docker.io.
Bitnami has deprecated its Debian based images, and removed the tags.
Gitea has not updated their Helm chart to reflect this change.

---

Trying Woodpecker.
Nice command to get values file for a Helm chart, to see options and adjust if needed.
```
helm show values oci://ghcr.io/woodpecker-ci/helm/woodpecker > values.yaml
```
If values are updated, you can do:
```
helm install woodpecker \
  oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  -f values.yaml
```

Woodpecker requires a forge to be setup, getting an error from the server pod:
```
can't setup globals: could not setup service manager: forge not configured
```
Setting up GitHub via OAuth client app.
Added these env vars:
```
WOODPECKER_GITHUB: "true"
WOODPECKER_GITHUB_CLIENT: Ov23lifIEwbb8eRsQl4Y
WOODPECKER_GITHUB_SECRET: xxx (in BitWarden)
```
Update Woodpecker via Helm:
```
helm upgrade --install woodpecker oci://ghcr.io/woodpecker-ci/helm/woodpecker -f values.yaml
```
By default there is no Ingress, so I'll add my own.
Ingress works, navigating to URL shows Woodpecker UI.
Login with github.com failes with error on server pod:
```
cannot register sguldemond. registration closed
```
Had to set WOODPECKER_OPEN to True. And remember to re-set the client token.
Now I can login and add my homelab repo.

---

Created a pipeline, got some errors in Woodpecker.
Couldn't easily run linter on the pipeline, so have to push fixes untill it works.
Seems like I cannot run images in privilged mode untill the project is set as trusted.
```
Insufficient trust level to use privileged mode
```
For this you need to be a admin, so I updated the WOODPECKER_ADMIN to "sguldemond" in the Helm values. 
After setting this up, I don't see the option to make the project "trusted".
Works, I needed to login and logout! Refresh the access token.
The CLI is available here: https://github.com/woodpecker-ci/woodpecker/releases
From the UI you can grab a token and locally do:
```
export WOODPECKER_SERVER="http://woodpecker.macmini.home"
export WOODPECKER_TOKEN="xxx"
```
Then you can run the cli locally, e.g.:
```
woodpecker-cli admin user ls
woodpecker-cli lint .woodpecker/build-push-portal.yaml
```
Getting stuck on this:
```
-> % woodpecker-cli exec .woodpecker/build-push-portal.yaml
🔥 .woodpecker/build-push-portal.yaml has 2 errors:
   ❌ steps.build-and-push	Insufficient trust level to use `privileged` mode
   ❌ services.buildkitd	Insufficient trust level to use `privileged` mode
6:22PM FTL error running cli error="config has errors"
```
Eventhough I gave the project all the trusted checks.
It could be that its just not working very well...

---

Shifting to GH Actions and publishing my portal image in Docker Hub. Widely accepted stack and flow.
GitHub Actions is getting stuck on building the image:
```
 > [build 8/8] RUN npm run build:
0.142 
0.142 > my-portal@0.0.1 build
0.142 > vite build
0.142 
0.146 sh: 1: vite: not found
``` 
Trying to simulate what the pipeline does:
```
docker buildx build -f Dockerfile .
```
This works.
Now running the pipeline using `act`, from repo root:
```
act --secret-file act.secrets workflow_dispatch
```
Act needs these secrets:
```
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
GITHUB_TOKEN
```
I can run it using `act`, and get the same error. So no closer to a solution.
Some odd behavior around building the poral on GH Actions.
For now I added `RUN npm install -g @sveltejs/kit vite` so the Runner can access `svelte-kit` and `vite`.
New error:
```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package '@tailwindcss/vite' imported from /app/node_modules/.vite-temp/vite.config.ts.timestamp-1759655627539-9542043a22014.mjs
```
Maybe since I install `vite` globally I need to install `@tailwindcss/vite` as well globally? Nope..
Appearantly I had to include dev specifically:
```
RUN npm ci --include=dev
```

---

Continuing the pipeline setup by adding the Kustomize override.
Testing it locally:
```
kustomize edit set image sguldemond/my-portal=sguldemond/my-portal:dev
kubectl kustomize base
```
Settings "Actions permissions" in my repo, with "Workflow permissions" to "Read and write permissions",
to allow pipeline to commit to the repo, and update image tag.
Had to set for it to work:
```
    permissions:
      contents: write
```

---

Installing ArgoCD:
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
ArgoCD is working!
Just not sure how ArgoCD knows about Kustomize.
The Deployment image is not updated, only the kustomazation.yaml is.
And the correct image is deployed. Want to know how this works.

Docs about Kustomize (https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/):
> If the kustomization.yaml file exists at the location pointed to by repoURL and path, Argo CD will render the manifests using Kustomize.

---

Setting up Ingress to reach ArgoCD from domain name:
https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#traefik-v30

Have to set argocd-server as `--insecure`.

---

Also want to export Application definition to my repo.
Done, see `projects/gitops/argocd-portal-app.yaml`.

---

I setup Tailscale VPN, and got access to the cluster from outside.
I updated the `k3s-config.yaml` to include the Tailscale IP addresses:
```
tls-san:
  - 192.168.1.100
  - 100.66.64.12
```
And updated the `ingress.yaml` to include the Tailscale IP addresses:

Would be nice to setup deployment via Ansible, but not a priority.
Requires maintaince of the playbook, not yet needed at this stage.

---

Starting with implementation of MetalLB.
MetalLB requires a Network Add-on, researching options.
K3s comes with Flannel as default, but I might have disabled it, not sure.

Interesting setup now where I have a network interface from Tailscale, `tailscale0`.
But my setup will requirest IPs from the router at home.

Disabling ServiceLB on k3s. It says to disable on all nodes,
but when adding:
```
disable:
  - servicelb
```
To the worker-node (macmini1) and running k3s-agent service restart it won't restart.

Starting of with Layer 2 mode which used the ARP protocol.
One node gets a IP address, and broadcasts its IP address to the network.

Installing MetalLB:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
```

After setting ip `IPAddressPool` and `L2Advertisement` my load balancers immediately got a new IP address from the range.

---

Bridging vs. Routing vs. NAT

| Mode | Layer | What it does | Typical use |
|------|-------|--------------|-------------|
| Bridge | 2 (Ethernet) | Forwards frames between interfaces | VMs in same LAN |
| Router | 3 (IP) | Moves packets between networks/subnets | Connecting LANs |
| NAT | 3+4 | Rewrites IPs to share one address | Internet access sharing |

Subnet mask

The subnet mask tells the system which portion of the IP address refers to the network and which portion refers to the host.

/24 → 24 bits of the address (out of 32) are for the network

The remaining 8 bits are for hosts

| CIDR | Mask | Network Range | Host Range | # Hosts |
|------|-------|--------------|-------------| ------- |
| /24 | 255.255.255.0 | 192.168.1.0 | 192.168.1.1–192.168.1.254 | 254 |
| /25 | 255.255.255.128 | 192.168.1.0 | 192.168.1.1–192.168.1.126 | 126 |
| /16 | 255.255.0.0 | 192.168.0.0 | 192.168.0.1–192.168.255.254 | 65,534 |

---

Side quest, installing Tailscale Kubernetes operator to expose some services to VPN with MagicDNS domain names.
```
helm upgrade \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  --set-string oauth.clientId="<OAauth client ID>" \
  --set-string oauth.clientSecret="<OAuth client secret>" \
  --wait
```

Want to expose ArgoCD over Tailscale via Ingress to give it a MagicDNS domain name and TLS.

Had to configure some stuff in Tailscale Web UI:
- Create tags: `k8s-operator` and `k8s`
- Create OAuth client to add to the operator with correct scopes: `auth_keys`, `devices:core`
- Enable HTTPS

Then I created a Ingress which assigns a domain name automatically, see `Address` of the Ingress.

---

Starting slow with setting up a Ansible playbook to configure a bridge between the two machines.
I have a simple setup where I can png both machines via Ansible:
```
USE_TAILNET=true ansible -K -i inventory.ini all -m ping
```

I'm not at home so I have to be careful with changing the networking settings.
I want to setup a bridge and connect both machines to it.
The current IP on the NIC will be disabled and the NIC will be attached to the bridge.
The bridge will provide the an IP address for the machines.

```
USE_TAILNET=true ansible-playbook -K -i inventory.ini playbooks/configure-bridge.yaml
```
For now Ansible cannot find the vars/interfaces.j2 file.
Moving it to the playbooks folder.

Everything works as expected, the bridge is setup and the machines are connected to it. I can ping both machines from the other.

---

Persisted the Tailscale install to a HelmChart manifest.
Finding out how I can see the logs I get from Helm usually.
A pod was created and completed, in this case `helm-install-tailscale-operator-mhwzn`, which has the logs.

---

Installing Jenkins via Terraform.
Created a new provider for Kubernetes and Helm.
Running `terraform init` and `terraform apply`.
Jenkins is running, but the Tailscale domain is not working yet.
Maybe something to do with the port.
Should add an Ingress instead, I like that approach, because it shows the URL in from kubectl/k9s.

---

Getting Jenkins pipeline working, starting of with manually adding it via the Web UI.
Setting up a way to build and push Docker container from the pipeline.
Trying out docker-workflow plugin: https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/docker-workflow
Have to add credentials to pipeline, but admin has no rights.

---

Pausing in Jenkins setup, adding my MacBook Pro to the cluster.
The plan is to setup a Proxmox cluster on all machines, which will provide me with a Hypervisor layer.
From there I can setup VMs that will run Kubernetes nodes and a virtual router for MetalLB BGP mode.

Not touching the Mac minis for now, first getting the MacBook setup.
I want to learn more about cloud-init, so I'll be using that in combination with Ubuntu Server, since it supports cloud-init better than Debian I've read.

With cloud-init I'll be setting up a virtual bridge as well, which I'll connect met NIC to.
The MacBook doesn't have built-in etherner, but I have a official Thunderbolt to ethernet adapter.
- Mac: ac:87:a3:13:08:10 (Ethernet adapter)
- Mac: 60:f8:1d:b1:a0:74 (WiFi)

Documentation on using the autoinstall feature via cloud-init:
- https://canonical-subiquity.readthedocs-hosted.com/en/latest/tutorial/providing-autoinstall.html#providing-autoinstall
- https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html

I removed the networking part, since it was throwing an error on install on de MBP.
The user password I created using `openssl passwd`.

The default network behavior let's the ethernet NIC retrieve an IP address over DHCP dynamically.
That is enough for now, I will setup the virtual bridge using Ansible later.
With the cloud-init+autoinstall I can SSH into the machine directly. I just need to check the IP address on the machine (or the router using the MAC address).
This makes the cloud-init YAML also more generic, since I don't have to know the MAC address of the NIC or have to set a static IP.

I have to disable the lid close behavior, on the MBP. I should intergrate this into the cloud-init setup.
Edited: `/etc/systemd/logind.conf`
```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
```
```
systemctl restart systemd-logind
```
Seems to work fine.

Change brightness:
```
sudo tee /sys/class/backlight/acpi_video0/brightness <<< 50
```

---

Installing Tailscale on the MBP so I can setup the bridge and still connect to it.

Added static IP for the MPB on the router (MAC address based).
Renewed DHCP lease:
```
sudo systemctl restart systemd-networkd
```

---

Switching gears. Installing Proxmox on top of Ubuntu is not recommended at all.
Installing Proxmox VE OS from USB on the MacBook now.

Also planning to get Kubernetes running via Talos Linux instead of K3s, which will hopefully help me with my CKA certification.
I will start with a single controle plane node VM with kube-vip to provide access to the API. Together with one worker node VM that will be a minimal cluster. When the Mac minis are Proxmox'd I will add a controle plane node VM per machine to run a HA k8s cluster, including some worker nodes.

Getting Proxmox OS running is really easy, it serves a web GUI which you can control the node.
Added my pub key manually, would be nice to do some auto install:
https://pve.proxmox.com/wiki/Automated_Installation

Downloading Talos ISO from: https://factory.talos.dev/
- Add `siderolabs/qemu-guest-agent` as instructed!

And following instructions for Proxmox: https://docs.siderolabs.com/talos/v1.11/platform-specific-installations/virtualized-platforms/proxmox

I need to add a EFI Disk of 4MB, figuring out how to create one in Proxmox.

---

macmini0 started spinning up it's fans every 30 seconds or so, I see CPU spike as well.
Looks like Loki is using the most CPU in those times, restarted a statefulset but still happening.
kubesystem coredns also spiking

Removed all Loki and Fluentbit stuff, still spiking, am I getting that much traffic? Cloudflare is not really showing crazy traffic.

At the end of the day turned off both Mac minis. This morning on startup no more fan spikes.
I do see more traffic then usual on Cloudflare, perhaps bots visiting the URL.

---

I can't get the Talos to boot properly.
I think it has not yet to do with Talos but with booting the ISO in Proxmox correctly.

The Talos docs on Proxmox says to use "ovmf" BIOS, this did not work for me.
I selected SeaBIOS (default) which did work.

Following the rest of the instructions got me to init a control plane node and kubectl to it!
Success!

---

I need a single IP when you have a HA control plane cluster.
I thought of using kube-vip, but Talos has its own solution.
Setting up a Virtual IP for the CP node for when I have multiple CP nodes:
https://docs.siderolabs.com/talos/v1.9/networking/vip

I added this to the `controlplane.yaml`:
```
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: true
        vip:
          ip: 192.168.1.70
```
This seems to be working.

---

Time to get something running, lets start with `whoami`.
For this I need Traefic.
I'm installing the Helm chart using Terraform so I have everything documented.

The LoadBalancer service is not getting a external-ip yet, so that is pending, which made Terraform wait.

Added MetalLB as well via Terraform, giving the Traefic LoadBalancer a IP from my routers DHCP service.

Applied the whoami manifests, almost there, got errors on the traefic pods:
```
│ traefik-9bfb99fc6-qx97t 2025-12-04T17:38:47Z INF Updated ingress status ingress=whoami-ingress namespace=whoami                                                                            │
│ traefik-9bfb99fc6-qx97t 2025-12-04T17:38:47Z ERR Cannot create service error="service not found" ingress=whoami-ingress namespace=whoami providerName=kubernetes serviceName=whoami-svc se │
│ traefik-9bfb99fc6-qx97t 2025-12-04T17:38:47Z ERR Cannot create service error="service not found" ingress=whoami-ingress namespace=whoami providerName=kubernetes serviceName=whoami-svc se │
```

Changing to a IngressRoute instead of Ingress gives me these errors:
```
│ 2025-12-04T20:21:14Z ERR error="kubernetes service not found: default/whoami-svc" ingress=whoami namespace=default providerName=kubernetescrd                                              │
│ 2025-12-04T20:21:37Z ERR error="kubernetes service not found: default/whoami-svc" ingress=whoami namespace=default providerName=kubernetescrd                                              │
```

Seems like a namespace issue, where Traefik is looking in default.

In order to re-apply Traefik via Terraform I had to run:
```
terraform import helm_release.traefik traefik/traefik
terraform import helm_release.metallb metallb/metallb
terraform plan
```

Issue around re-applying MetalLB now, interesting resource to check in k8s:
```
kubectl -n metallb get events --sort-by=.metadata.creationTimestamp | tail -n 30
```
Or just check k9s ==> `:events`

This issue on GitHub helped me fix deploying MetalLB: https://github.com/siderolabs/talos/issues/10291
I had to add some labels to the namespace:
```
pod-security.kubernetes.io/audit: privileged
pod-security.kubernetes.io/enforce: privileged
pod-security.kubernetes.io/enforce-version: latest
pod-security.kubernetes.io/warn: privileged
```
It seemed like initially installing MetalLB went okay, but I might be wrong here.

Continueing with getting Traefik working.
Installing via Terraform keeps it in `pending-install` state.
Doing it directly using helm command works:
```
helm upgrade --install traefik oci://ghcr.io/traefik/helm/traefik -f values/traefik.yaml -n traefik --create-namespace --debug
```
But! The External-IP keep state `<pending>`. Which is odd, since it did get it the first time I tried it.
What changes is that I now am using a Virtual IP for Talos, this might influence stuff.
I have to still apply the MetalLB manifests! This immediatly gives the Traefik LoadBalancer a external-ip.

Apperantly the Service had to be defined before the Ingress(Route) for it to work.
Although I had this working on k3s (I thought...).

---

Installing OPNSense on Proxmox.
I added to network interfaces to the VM.
- vmbr0: default bridge by Proxmox, connected to the physical NIC of the machine (MacBook)
- vmbr1: newly created bridge without any NIC or IP (yet)

From OPNSense console I had to configure both interfaces.
The vmbr0 would be the WAN (Wide Area Network) side, connected to my router ISP.
vmbr1 would be the LAN side, which gets its own subnet (192.168.2.1/24 in this case).
The Talos VMs will connect then connect to vmbr1 instead of vmbr0 and get their IP from OPNSense DHCP.

Haven't been able to connect to the Web GUI yet. The WAN IP was not responsing, and the LAN ip is not accessible from my machine.

Also Traefik has stopped working again...

I can access the web GUI via the WAN IP when I disable the firewall in the shell (`pfctl -d`, to re-enable: `pfctl -e`).
There should be a way to setup access via WAN securily via the web interface, haven't found that yet.

Trying the steps described here: https://forum.opnsense.org/index.php?topic=36950.0
```
1. Go to Interfaces > [WAN] deselect "Block private networks"
2. Go to Firewall > Rules > WAN and create a new rule using below parameter save then apply.

  Action : Pass
  Interface : WAN
  Direction : In
  TCP/IP Version: IPv4
  Protocol: any
  Source: WAN net
  Destination: any
  Destination port range: any
  Gateway: default
  repeate this for IPv6

3. Go to Firewall > Settings > Advanced and tick "Disable reply-to (Disable reply-to on WAN rules)"
4. Reboot (Very Important)
```
This worked! I can now access the web GUI from the WAN IP.

Ofcourse now I'm in for some fun.
I have switched the network interface of the two Talos VMs to vmbr1, which first of all makes it not directly accessible from my machine.
I can do some port forwarding in OPNSense in order to forward traffic from the WAN IP with k8s API port (6443) to the new internal LAN IP of the control plane node. But that doesn't just work, like I expected.
I can either completely re-install Talos on both VMs starting of with the now internal LAN IP, or try to figure out what I can do to get it working without... Reinstall takes a while, figuring out how to fix it as well.

---

Setting up a Ubuntu Server VM in order to access everything inside the OPNSense LAN, like Talos (talosctl, kubectl).
Using Cloud-Init feature, needed to download a cloud image of Ubuntu from https://cloud-images.ubuntu.com/noble/current/.
The .img is not like a .iso, you cannot boot from it by attaching it to a CDROM drive.
I changed the size of the img, following https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs:
```
qemu-img resize noble-server-cloudimg-amd64.img 16G
```
And now going to mount that as the main drive.
```
qm importdisk 104 noble-server-cloudimg-amd64.img local-lvm
```
This is working. Using a cloud-image is different from using a ISO install in that the img is already pre-configured for usage within a cloud setting. No installer is needed, the cloud-init vars are used to create a user, add SSH key etc and you can start using the VM, pretty cool.

---

I have successfully updated the IP and VIP related to the control plane node.
I changed the references to both in the `controlplane.yaml`, transferred this file to my Ubuntu VM and applied the changes there.
On my machine:
```
scp controlplane.yaml proxmox-ubuntu:/home/stan/talos-cluster
```
On the Ubuntu VM:
```
talosctl apply-config --nodes 192.168.2.59 --file talos-cluster/controlplane.yaml
```
Talos seems quite reactive to these kind of changes, unlike k3s.

---

Want to port forward the calls to the WAN IP on 6443 to the Talos VIP so I don't need the Ubuntu VM.
It is not working as expected, trying setting up WireGuard instead.

I have WireGuard working with OPNSense and Ubuntu.
This guide has most information: https://docs.opnsense.org/manual/how-tos/wireguard-client.html

I'm using this config on Ubuntu:
```
[Interface]
PrivateKey = < private key from client! >
Address = 10.0.0.2/32
DNS = 192.168.2.1

[Peer]
PublicKey = < public key of wireguard instance in opnsense! >
Endpoint = 192.168.1.51:51820
AllowedIPs = 192.168.2.0/24, 10.0.0.0/24
PersistentKeepalive = 25
```

Firewall → Rules → WireGuard

Add rule:
- Interface: WireGuard
- Source: 10.0.0.0/24
- Destination: LAN net
- Description: Allow WG clients to LAN

Also add:
- Interface: WireGuard
- Source: 10.0.0.0/24
- Destination: This firewall
- Description: Allow WG to reach OPNSense itself

Without this rule you cannot reach 192.168.2.1.

---

I'm going to clean up my repo so I can commit my changes.
Need to encrypt some secrets, trying SOPS in combination with age.

Created age key:
```
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Added .sops.yaml in repo main:
```
keys:
  - &me age13hp3zvzjr8pvctd99lwhy6wunmcjgkfgjp58amcsykzql400jp3sr5cyht

creation_rules:
  - path_regex: projects/proxmox/talos/.*\.ya?ml$
    key_groups:
      - age:
          - *me
```

Encrypted my YAML files:
```
sops -e -i controlplane.yaml
sops -e -i worker.yaml
sops -e -i talosconfig.yaml
```

In order to use the encrypted file I have two options:
```
sops -d talos/controlplane.yaml | talosctl apply-config \
  --nodes 192.168.2.59 \
  --file /dev/stdin
```
```
sops -d talos/controlplane.yaml > cp.dec.yaml
talosctl apply-config --nodes 192.168.2.59 --file cp.dec.yaml
rm cp.dec.yaml
```

---

I can connect via Tailscale as well using the `os-tailscale` plugin.
This requires me to update OPNSense though:
```
***GOT REQUEST TO INSTALL***
Currently running OPNsense 25.7 (amd64) at Tue Dec  9 20:27:27 UTC 2025
Installation out of date. The update to opnsense-25.7.9 is required.
***DONE***
```

---

I have my Thunderbolt-Ethernet cable and I setup my new hardware arrangement.
Now going to install OPNSense directly on the 2014 Mac mini, which now has two NICs.

I dd'd the ISO onto my USB, but it's not showing up in the post-Alt screen on the Mac mini (yet).
```
sudo dd if=/home/stan/Downloads/OPNsense-25.7-dvd-amd64.iso of=/dev/sdb bs=4M status=progress oflag=sync
```

 Downloading the "vga" version which is a `.img` file as instructed in the docs (https://docs.opnsense.org/manual/install.html#installation-media).
 ```
 sudo dd if=/home/stan/Downloads/OPNsense-25.7-vga-amd64.img of=/dev/sdb bs=16k status=progress oflag=sync
 ```

 I can already check the MAC addresses of the two NIC on the current Debian install.
 - enp3s0f0: 0c:4d:e9:c6:85:30, should become WAN
 - ens9 (enp9s0): 0c:4d:e9:d1:54:11, should become LAN

 I need to give the WAN side a static IP on my ISP router.

OPNSense it setup and working on the Mac mini, there is an option for auto config, would be good to document the settings.
Here a quick overview:
- Set WAN and LAN to correct NICs
- WAN gets static IP from ISP router (192.168.1.100)
- LAN sets static IP: 192.168.2.1/24
- Enable DHCP on LAN with range .10 > .100

---

I added the `os-tailscale` community plugin to OPNSense, can't find proper documentation on its use.
Had to restart OPN to see the options. Options are available via VPN > Tailscale.
Under Settings you need to enable Tailscale first, then under Status you can get the auth link.
I enable Accept Subnet Router, with an Advertised Route of 192.168.2.0/24 (LAN).
In the Tailscale dashboard under `opnsense` I still needed to confirm that this subroute is legit.

To setup Firewall rules I need to first assign the Tailscale interface `tailscale0` to OPNSense via Interfaces > Assignment.
Under the OPNSense shell (FreeBSD) using `ifconfig -a` you can see the interfaces as well.
Also don't forget after creation to Enable the interface, now I can set Firewall rules to allow access to LAN net via Tailscale.

Firewall → Rules → Tailscale

```
Action: Pass
Interface: Tailscale
Source: Tailscale net
Destination: LAN net
Description: Allow Tailscale access to Lab LAN
```

```
Action: Pass
Interface: Tailscale
Source: Tailscale net
Destination: This Firewall
Description: Allow Tailscale access to OPNsense
```

Finally on my laptop I have to run the following command:
```
sudo tailscale set --accept-routes
```
As explained here: https://tailscale.com/kb/1019/subnets#use-your-subnet-routes-from-other-devices

Also usefull to disable key expiry of the opnsense machine in Tailscale dashboard via "Machine settings".

I might have to run this everytime I start Tailscale on my machine:
```
sudo tailscale up --accept-routes
```

But it works, I can ping the LAN address of OPNSense Mac mini.

---

Reattaching the MacBook to the new Lab LAN.
Edited `/etc/network/interfaces` and ran `ifreload -a`, but got a error that no IP was found for vmbr0.
After reboot it worked again.

---

Haven't worked on my lab for a few days, can't reach the OPNSense router via the LAN IP.
Expected to be able to via Tailscale, `ip route show` is not showing the Lab LAN subnet:
```
-> % ip route show
default via 192.168.1.1 dev wlp61s0 proto dhcp src 192.168.1.179 metric 600 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
172.18.0.0/16 dev br-9fee8da751a1 proto kernel scope link src 172.f18.0.1 linkdown 
172.19.0.0/16 dev br-f24dc19acc19 proto kernel scope link src 172.19.0.1 linkdown 
172.20.0.0/16 dev br-0b98cec484ef proto kernel scope link src 172.20.0.1 
172.21.0.0/16 dev br-444ba1ec82d0 proto kernel scope link src 172.21.0.1 linkdown 
172.22.0.0/16 dev br-bbad8fd4fad4 proto kernel scope link src 172.22.0.1 linkdown 
192.168.1.0/24 dev wlp61s0 proto kernel scope link src 192.168.1.179 metric 600 
```

Not getting an IP after physically connecting to the Lab LAN using Ethernet on my laptop either.
Seems like the router is not responding, Home LAN IP is not responding to ping either.
Attached monitor and keyboard to router. When I disable the firewall I can ping it.
It can ping the ISP router as well, and get into the web GUI via the WAN IP, using http://<wan-ip>.

I see that the LAN interface has the device `bge1`, but it says "missing". Also I don't see it using `ifconfig -a`.
The switch light is green though, so I don't think the Thunderbolt adapter is dead.
Not ideal, but rebooting system, see if it shows up again. I see it in the startup logs already present.
It's back after the reboot, could be that OPNSense/FreeBSD disconnected the NIC and didn't reconnect.

---

I want to know how Tailscale routes the requests to the Lab LAN via the Tailscale interface to to router.
It is not showing up in my `ip route show` results.

It is showing when checking all tables, not just `main` (default):
```
-> % ip route show table all | grep tailscale -n
1:100.83.153.29 dev tailscale0 table 52 
2:100.83.234.73 dev tailscale0 table 52 
3:100.93.235.14 dev tailscale0 table 52 
4:100.100.100.100 dev tailscale0 table 52 
5:100.111.248.12 dev tailscale0 table 52 
6:100.111.255.7 dev tailscale0 table 52 
7:192.168.2.0/24 dev tailscale0 table 52 
```

Usefull:
```
-> % ip route get 192.168.2.1                   
192.168.2.1 dev tailscale0 table 52 src 100.109.194.44 uid 1000 
    cache 
```
Also involves `ip rule` setting "Policy decision" which I don't fully understand yet.

---

The MBP with Proxmox is connected to the router and the Talos VMs have their new IPs.
The traefik service still has a 192.168.1.xxx IP, which needs to be updated.

---

Thunderbolt Ethernet on Mac mini with OPNSense (FreeBSD) failed again.
I now have the logs:
```
bge1: firmware handshake timed out, found 0xffffffff
brgphy1: detached
miibus1: detached
bge1: detached
pci9: detached
pcib9: detached
pci8: detached
pcib8: detached
pci7: detached
```

"This is a hard device failure from the OS point of view."
FreeBSD forum responses on the "bge" driver doesn't look hopefull.

---

Moving to VyOS, a Linux kernel based router, all CLI based.
Or not, no GUI, just CLI, seems cool, but after install I got no screen.

Let's play it "safe" and install Proxmox on the Mac mini and get OPNSense on there.
Have that setup, in order to install Tailscale on the Proxmox OS I had to disable Enterprise repo's in the settings.

Also I have to do some cert stuff: https://tailscale.com/kb/1133/proxmox#enable-https-access-to-the-proxmox-web-ui
Adding the certs enables SSL over the Tailscale URL of the Mac mini: https://macmini.tail9271d2.ts.net:8006/

Curious if I can just add the subnet to Tailscale settings in OPN and will be able to reach the MBP again.

---

Playing around with VyOS on Proxmox now. Installed it.
Setup for WAN IP:
```
configure
set interfaces ethernet eth0 description 'WAN'
set interfaces ethernet eth0 address dhcp
commit
ip a
save
```

---

Setting up a Ubuntu Server VM as exit node via Tailscale.
This way I can flow traffic via The Netherlands while I'm in Poland.

Pasting in a Proxmox VM seems a common issue.

Adding a serial port via Hardware and running this in the VM:
```
sudo systemctl enable serial-getty@ttyS0.service
```
works, then I can get a shell via the Proxmox OS:
```
qm terminal <VMID>
```
Now I can install Tailscale on the VM and SSH to it from my machine.
After install I ran:
```
sudo tailscale up --advertise-exit-node
```
In Tailscale I have to allow the machine to be an exit node.
Also I have to enable IP forwarding on the VM as explained here: https://tailscale.com/kb/1019/subnets?tab=linux#enable-ip-forwarding
```
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

---

Installed Tailscale on VyOS using by downloading the binary files and supporting systemd files from: https://pkgs.tailscale.com/stable/#static
- curl'd the tgz & unpacked it
- moved the files inside to the right place, based on how it is on my laptop

Adding my SSH public key uses this command (https://docs.vyos.io/en/latest/configuration/service/ssh.html):
```
generate public-key-command user vyos path id_rsa_t480s.pub
```

I can now access VyOS using my SSH key, so I disabled password auth:
```
set service ssh disable-password-authentication
```

I've setup a DHCP server, serving IPs on the 192.168.2.0/24 subnet (https://docs.vyos.io/en/latest/configuration/service/dhcp-server.html).
- Set subnet id: 1
- Set start and stop range: *.10 --> *.100
- DNS (name-server): 192.168.2.1
- Default route: 192.168.2.1

I would want to access my MacBook now, which is only connected to Lab LAB, but it might be stuck with a old DHCP lease of the old OPNSense setup.
Could check up in 12-24h to see of the lease expired and VyOS has served it a new IP now, would be cool.
```
show dhcp server leases
```

Btw, I have a backup of the VyOS config using:
```
scp vyos:/config/config.boot /my/path/config.boot
```

---

The DHCP refresh didn't take place, so I don't have access to my MacBook Pro connected to only Lab LAN.

So I'm doing a little side project where I expose this file via a simple MkDocs setup.
Hosting it using GitHub Pages, setting up a redirect of homelab.stansyfert.com to the GH Pages of the Homelab repo.

This file will be reverted and the README will be slighly adjusted to render nicely.
Cursor created some scripts for this which worked and I haven't really looked at, let's see how long those hold up.

For the domain to GH Pages redirect I'm following: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site

They recommend to add my domain to my GH account, did that, so waiting for DNS records to update:
https://github.com/settings/pages_verified_domains/stansyfert.com

When that is setup I should follow this: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-a-subdomain

---

Back at it (02-02-2026).
Want to get an IP on the MBP from the DHCP server running on VyOS VM on the Mac mini.
After system reboot and `ifreload -a` no luck.
Would VyOS be handing out IPs correctly?

Connecting my laptop to the LAB switch is also not giving me an IP on the 192.168.2.1/32 subnet.
so seems like VyOS indeed.

---

I didn't change VyOS (I think).
On the Ubuntu VM (same machine, but also get both NICs),
I added a netplan config:
```
$ sudo vim /etc/netplan/60-cloud-init.yaml
network:
  version: 2
  ethernets:
    enp6s19:
      match:
        macaddress: "bc:24:11:f9:b9:dc"
      dhcp4: true
      set-name: "enp6s19"
```

Applying it: `sudo netplan apply`,
gives me a IP address now and I can reach the VyOS and vice versa!
So DHCP is working on VyOS! Small win there, got me into understanding netplan a bit again.

Looks like the Thunderbolt NIC is not being loaded on the Proxmox OS on Ubuntu,
so my Ubuntu VM is getting an IP since VyOS is making it available on vmbr1,
but nic1 is connecting to vmbr1, which I though it was.
Is this again the badly supported Thunderbolt Ethernet NIC chasing me...?

Success! Got an IP on my laptop, doesn't bode well for my Thunderbolt Ethernet though...
When it happens again, should look into the logs.

```
vyos@vyos:~$ show dhcp server leases
IP Address    MAC address        State    Lease start                Lease expiration           Remaining    Pool    Hostname       Origin
------------  -----------------  -------  -------------------------  -------------------------  -----------  ------  -------------  --------
192.168.2.10  bc:24:11:f9:b9:dc  active   2026-02-03 10:38:51+00:00  2026-02-04 10:38:51+00:00  23:41:08     LAB     ubuntu-server  local
192.168.2.11  bc:24:11:af:6d:02  active   2026-02-03 10:56:00+00:00  2026-02-04 10:56:00+00:00  23:58:17     LAB     talos-v1v-p8m  local
192.168.2.12  bc:24:11:7c:fb:b6  active   2026-02-03 10:56:19+00:00  2026-02-04 10:56:19+00:00  23:58:36     LAB     talos-j2r-sow  local
192.168.2.13  00:e0:4c:4d:22:a0  active   2026-02-03 10:56:25+00:00  2026-02-04 10:56:25+00:00  23:58:42     LAB     tp1-ubuntu     local
```

Looks like the MBP VMs are getting an IP now from VyOS,
now need to get into the Proxmox UI of the MBP.
This works, need to install Tailscale on this Proxmox instance as well.

---

Need to setup VyOS so LAB devices can reach the internet.
I think I need to setup (S)NAT as well as DNS.
- https://docs.vyos.io/en/latest/quick-start.html#nat
- https://docs.vyos.io/en/latest/quick-start.html#dhcp-dns-quick-start

I think I've setup NAT correctly, the MBP can reach the internet now:
```
set nat source rule 100 outbound-interface name 'eth0'
set nat source rule 100 source address '192.168.2.0/24'
set nat source rule 100 translation address masquerade
```
Some docs: https://docs.vyos.io/en/latest/configuration/nat/nat44.html#source-nat

Now need to setup DNS!  
```
set service dns forwarding cache-size '0'
set service dns forwarding listen-address '192.168.2.1'
set service dns forwarding allow-from '192.168.2.0/24'
```
This worked as well, domain names now resolve to IPs on the MBP.

---

Decided to already step away from Talos, although cool,
now want to try RKE2, alternative to K3s.

Talos is working on my MBP, so I'll leave that for now.
I can use the other Mac mini to try out RKE2.

Just quickly set stuff up:
- Gave MBP a static IP: 192.168.2.2
- Advertising 192.168.2.0/24 subnet via VyOS using tailscale (`tailscale set --advertise-routes=192.168.2.0/24`)
- Accepted routes on Thinkpad (`tailscale set --accept-routes`), no need for physical connection to Lab LAN, should be able to access everything remotely
- Tested if I can reach my whomai service on Talos, no problems, needed to update the MetalLB routes matching the Lab LAN network
- Installing Proxmox OS on macmini1, with static IP: 192.168.2.3
- Mount USB and copy ssh pub key to Proxmox:
  - mkdir /mnt/usb
  - mount /dev/sdb5 /mnt/usb
  - cat /mnt/usb/key.txt >> ~/.ssh/authorized_keys
- Setup Proxmox cluster on MBP: `pvecm add lab`
- Added macmnini1 to cluster: `pvecm add 192.168.2.2 --use_ssh 1`

Cluster setup failed, I broke both Proxmox machines, ChatGPT helped me recover them!
Not trying that again...

---

Setup the second Mac mini with Proxmox running a Ubuntu Cloud image VM with RKE2 installed,
followed the docs here: https://docs.rke2.io/install/quickstart
Docs are simple and clear, added the .../bin to PATH, copied the kubeconfig.
Little confusion when `systemctl start rke2-server` got stuck, printing issues with connection to 127.0.0.1:2379 (etcd),
but cancelling the operation and starting it again it worked immediatly, maybe some race condition.

Right of the bet, memory usage of the RKE2 master node is quite significant!
Close to 4GB all together with the node OS (Ubuntu).

Accessing the cluster from my machine it possible using the LAB IP, via the subnet forwarding on VyOS VM.
Want to install and try out OpenBao, but not gonna bother with Terraform and stuff, just imperativaly.

```
helm install openbao openbao/openbao -n openbao --create-namespace
```

OpenBao needs PersistentVolume or default storage class to start a pod:
```
  Normal  FailedBinding  11s (x8 over 107s)  persistentvolume-controller  no persistent volumes available for this claim and no storage class is set
```

Installed: https://github.com/rancher/local-path-provisioner
Pod is not running.

```
k exec -it -n openbao openbao-0 -- sh
$ bao secrets enable kv
Success! Enabled the kv secrets engine at: kv/
```
Docs: https://openbao.org/docs/commands/secrets/enable/

```
/ $ bao kv put secret/my-first-secret name=stansyfert
======= Secret Path =======
secret/data/my-first-secret

======= Metadata =======
Key                Value
---                -----
created_time       2026-02-06T13:20:07.449345348Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

Want to load scecret into pod using CSI driver: https://openbao.org/docs/platform/k8s/csi/examples/

Installed CSI Secret Store Driver: https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation,
and created SecretProviderClass pointing to my-first-secret.

Had to enable the Openbao CSI provider in Helm install:
```
...
csi:
  enabled: true
```
upgrade release:
```
helm upgrade openbao openbao/openbao -n openbao -f ~/Development/DevOps/homelab/projects/openbao/values.yaml
```

Now getting:
```
  Warning  FailedMount  3s (x5 over 11s)  kubelet            MountVolume.SetUp failed for volume "openbao-first-secret" : rpc error: code = Unknown desc = failed to mount secrets store objects for pod openbao/demo-app-5574d78dc4-rhw9v, err: rpc error: code = Unknown desc = error making mount request: couldn't read secret "my-first-secret": failed to login: Error making API request.
```

I think secret path should be: `secretPath: "secret/my-first-secret"`,
based on this:
```
/ $ bao kv get secret/data/my-first-secret
No value found at secret/data/data/my-first-secret
/ $ bao kv get secret/my-first-secret
======= Secret Path =======
secret/data/my-first-secret
...
```

Still not working after recreating the SecretProviderClass,
maybe it has to do with the "failed to login" part.

creates SA:
```
k create sa -n openbao demo-app
```

```
bao auth enable kubernetes
bao write auth/kubernetes/role/demo-app \
    bound_service_account_names=demo-app \
    bound_service_account_namespaces=openbao \
    policies=default \
    ttl=1h
```

New error:
```
│   Warning  FailedMount  26s   kubelet            MountVolume.SetUp failed for volume "openbao-first-secret" : rpc error: code = DeadlineExceeded desc = failed to mount secrets store obje │
│ cts for pod openbao/demo-app-6f8bf7fb98-245b5, err: rpc error: code = DeadlineExceeded desc = error making mount request: couldn't read secret "my-first-secret": failed to login: context │
│  deadline exceeded
```

Seeing this in the openbao-0 logs, might be related:
```

WARNING! dev mode is enabled! In this mode, OpenBao runs entirely in-memory
and starts unsealed with a single unseal key. The root token is already
authenticated to the CLI, so you can immediately begin using OpenBao.

You may need to set the following environment variables:

    $ export BAO_ADDR='http://[::]:8200'

The unseal key and root token are displayed below in case you want to
seal/unseal the Vault or re-authenticate.

Unseal Key: ma7kWLthWXy/4XOCCJcLHo4GTtFDnp2t8jn9L+E9jvQ=
Root Token: root

Development mode should NOT be used in production installations!
```

---

Been talking with ChatGPT for a while!
Result is that I want to install Fedora CoreOS on macmini1,
with k3s (probably).
Also instead of a static IP VyOS should make a DHCP reservation for the macmini1 mac address:
```
vyos@vyos# set service dhcp-server shared-network-name LAB subnet 192.168.2.0/24 static-mapping macmini1 mac '0c:4d:e9:9a:70:aa'
vyos@vyos# set service dhcp-server shared-network-name LAB subnet 192.168.2.0/24 static-mapping macmini1 ip '192.168.2.20'
vyos@vyos# set service dhcp-server shared-network-name LAB subnet 192.168.2.0/24 static-mapping macmini1 description 'macmini1-coreos'
```

For CoreOS I'm using the Ignition feature to bootstrap the server,
this JSON file can be generated from a Butane YAML file,,
docs: https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/

Call this in the same directory as the Butane file:
```
alias butane='podman run --rm --interactive         \
              --security-opt label=disable          \
              --volume "${PWD}:/pwd" --workdir /pwd \
              quay.io/coreos/butane:release'
butane --pretty --strict macmini1-butane.yaml > macmini1.ign
```

Installing CoreOS on Mac mini,
had to unset some LVM stuff (not sure what, LLM told me what to do),
after /dev/sda3 was being busy.

after I ran:
```
sudo widefs -a /dev/sda
```
because on this forum someone needed to do that:
https://discussion.fedoraproject.org/t/installing-bare-metal-on-mac-mini-late-2012-fails-with-fsconfig-system-call-failed-dev-disk-by-label-root-cant-lookup-blockdev/127241/7

Install worked, but my user had no password,
so reinstalling.
This time serving the Ignition file (macmini1.ign) from my laptop:
```
butane --pretty --strict macmini1-butane.yaml > macmini1.ign
python3 -m http.server 8080
```

From the coreos installer:
```
sudo coreos-installer install /dev/sda --insecure-ignition --ignition-url http://192.168.1.179:8080/macmini1.ign
```
This way I don't have to add the .ign file to the USB again,
which I did the first time, I mounted the seperate USB partition locally:
```
sudo mkdir -p /mnt/usb
sudo mount /dev/sda3 /mnt/usb
```

So far no issues with installing CoreOS on the Mac mini 2012,
seems to run fine, which is exciting,
this type of bootstrap booting and serving the config over HTTP,
was what I was trying way back in the beginning of my Homelab journey with Ubuntu,
that didn't work so smoothly, or at all really,
I learned a bit about CloudInit and cloud images though, still usefull.

Re-leasing the IP on VyOS is still a bit of a puzzle.
This did work:
```
vyos@vyos:~$ clear dhcp-server lease 192.168.2.24
Lease "192.168.2.24" has been cleared
```
Mac mini still has this IP though.

The static IP I chose, was already taken by other machine.
Changed it to: 191.168.2.60,
removed the lease on VyOS,
reconnected the eth device on CoreOS:
```
sudo nmcli device disconnect enp1s0f0 && sudo nmcli device connect enp1s0f0
```

---

Installing k3s on CoreOS Mac mini now...
with no issues at all,
can access the k3s node from my laptop, also added some extra tls-san:
```
tls-san:
  - "macmini1"
  - "macmini1.tail9271d2.ts.net"
  - "100.69.168.103"
  - "192.168.2.60"
```
