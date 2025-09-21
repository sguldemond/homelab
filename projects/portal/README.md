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
