# Portal

Simple WebUI with read access to cluster.

Stack:
- SvelteKit
    - Serves API with access to k3s cluster via ServiceAccount token
    - Client consuming real time API
- RBAC
    - ServiceAccount
    - ClusterRole
    - ClusterRoleBinding

Insight into code:
```ts
import * as k8s from '@kubernetes/client-node';

const kc = new k8s.KubeConfig();
kc.loadFromCluster();
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const res = await k8sApi.listPodForAllNamespaces();
```

Insight into manifests:
```yaml
kind: ServiceAccount
metadata:
  name: portal-readonly
```
```yaml
kind: Deployment
...
spec:
  serviceAccountName: portal-readonly
```