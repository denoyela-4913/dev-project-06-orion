terraform {
  required_version = "~> 1.17"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # État local pour l'instant : aucun hébergement n'est choisi. Un état distant et verrouillé est nécessaire dès
  # que plusieurs personnes ou la CI déploient sur le même cluster (cf. docs/BACKLOG.md).
  backend "local" {}
}
