# Socle d'un environnement : l'espace de noms et ses garde-fous. Rien de propre à l'application ici.

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of"    = "microcrm"
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment

      # Niveau « restricted » des normes de sécurité des pods : Kubernetes refuse tout pod qui tourne en root,
      # peut gagner des droits ou garde des capacités autres que NET_BIND_SERVICE.
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = "environment-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = {
      pods               = var.quota.pods
      "requests.cpu"     = var.quota.requests_cpu
      "requests.memory"  = var.quota.requests_memory
      "limits.memory"    = var.quota.limits_memory
      "requests.storage" = var.quota.storage
    }
  }
}

# Valeurs par défaut des conteneurs qui n'en déclarent pas (pod temporaire de sauvegarde, tests) : sans elles,
# le quota les refuserait.
resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "container-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        memory = "256Mi"
      }
      default_request = {
        cpu    = "20m"
        memory = "64Mi"
      }
    }
  }
}
