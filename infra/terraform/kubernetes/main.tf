# --- Traefik ---
resource "helm_release" "traefik" {
    namespace = "traefik"
    create_namespace = true
    name = "traefik"
    repository = "https://traefik.github.io/charts"
    chart = "traefik"
    values = [file("${path.module}/values/traefik.yaml")]
}

# --- MetalLB ---
resource "kubernetes_namespace" "metallb" {
    metadata {
        name = "metallb"
        labels = {
            "pod-security.kubernetes.io/audit"           = "privileged"
            "pod-security.kubernetes.io/enforce"         = "privileged"
            "pod-security.kubernetes.io/enforce-version" = "latest"
            "pod-security.kubernetes.io/warn"            = "privileged"
        }
    }
}

resource "helm_release" "metallb" {
    name = "metallb"
    repository = "https://metallb.github.io/metallb"
    chart = "metallb"
    namespace = kubernetes_namespace.metallb.metadata[0].name
}
