# Portal

Simple web UI with read access to cluster.

Stack:
- SvelteKit
    - Serves API with access to k3s cluster via ServiceAccount token
    - Client consuming real time API, SSE?
- RBAC: ServiceAccount, ClusterRole, ClusterRoleBinding