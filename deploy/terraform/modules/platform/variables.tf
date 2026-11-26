variable "namespace" {
  description = "Espace de noms de l'environnement."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "Nom d'espace de noms Kubernetes invalide."
  }
}

variable "environment" {
  description = "Nom de l'environnement."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environnement attendu : dev, staging ou production."
  }
}

variable "quota" {
  description = "Plafonds de l'espace de noms."
  type = object({
    pods            = number
    requests_cpu    = string
    requests_memory = string
    limits_memory   = string
    storage         = string
  })
}
