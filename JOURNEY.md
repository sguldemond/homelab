# Journey

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
```
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