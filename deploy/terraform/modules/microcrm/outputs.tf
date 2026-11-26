output "release_name" {
  value = helm_release.microcrm.name
}

output "front_service" {
  description = "Service à joindre (port-forward) quand l'ingress est désactivé."
  value       = "${helm_release.microcrm.name}-front"
}
