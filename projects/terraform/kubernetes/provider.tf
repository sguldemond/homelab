terraform {
    required_version = ">= 1.6.0"
    required_providers {
        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "~> 2.38"
        }
        helm = {
            source = "hashicorp/helm"
            version = "~> 3.0"
        }
    }
}

provider "kubernetes" {
    config_path = var.kubeconfig_path
}

provider "helm" {
    kubernetes = {
        config_path = var.kubeconfig_path
    }
}