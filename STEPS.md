# Steps

## TODO

- Host static files blog
- Learn Traefic
- Study k3s setup: nodes, 


## Install k3s

- Run k3s install script
- Copy k3s.conf to user folder for `kubectl` access

## Access to cluster

- Setup SSH access
- Configure static IP on WLAN router
- Add shortname to `/etc/hosts` to Homelab
- Copy kube config to local machine for `kubectx`
- Recreate TLS certs for new machine IP:
```
# /etc/rancher/k3s/config.yaml
tls-san:
  - 192.168.1.100         # your new reserved LAN IP
  - macmini.lan           # optional: your local DNS name, if any
  - 100.x.y.z             # optional: your Tailscale IP if you’ll use it
```
```
sudo systemctl restart k3s
```

## Configure k3s cluser

- Starting off with a single node:
```
-> % k get nodes
NAME      STATUS   ROLES                  AGE    VERSION
macmini   Ready    control-plane,master   174m   v1.33.3+k3s1
```
- kubectl is responding very flacky
    - Watch `top` and see some spikes
    - Disabled Traefik and metrics-server in k3s config
    - The old IP was configured deep into k3s which is causing issues
    - Trying to remove the node failing
    - Purges k3s from machine and reinstalled it with default settings


## Host container registry

- Start Registry from online example
- Test by pushing containers
- Setup reference to local registry in k3s
    - https://docs.k3s.io/installation/private-registry
    - Add `/etc/rancher/k3s/registries.yaml` with config
- When adding extra node to k3s, add it there as well
- After adding restart `k3s` (control-plane node) or `k3s-agent` (worker node) via `systemctl`


## Setup observability

- Stack: Fluent Bit, Loki, Grafana
- Start with Loki and test adding log records via API
- Install Loki via Helm: https://grafana.com/docs/loki/latest/setup/install/helm/
- Managed to create a values form, but documentation is very unclear
    - Important to add `auth_enabled: false`
- Install Fluent Bit via Helm with custom config
    - Verify that vlaues.yaml is read: `helm upgrade --install fluent-bit fluent/fluent-bit -n fluent-bit --create-namespace -f fluent-bit-values.yaml`
- Install Grafana
```
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
- Add Loki dashboard to Grafana, e.g.: https://grafana.com/grafana/dashboards/13639-logs-app/
- Add persistent storage to loki StatefullSet, now its stored in de pod on /tmp/loki.
- Deploy Grafana via resources
