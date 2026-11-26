output "namespace" {
  description = "Nom de l'espace de noms créé."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
