variable "namespace" {
  description = "Espace de noms, déjà créé par le module platform."
  type        = string
}

variable "environment" {
  description = "Environnement : choisit le fichier values-<environnement>.yaml du chart."
  type        = string
}

variable "image_tag" {
  description = "Version des images à déployer."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-Za-z][0-9A-Za-z._-]*$", var.image_tag))
    error_message = "Version d'image invalide ou vide."
  }
}

variable "image_repository_prefix" {
  description = "Préfixe du registre avec le « / » final (ex. ghcr.io/<propriétaire>/<dépôt>/). Vide : images locales."
  type        = string
  default     = ""

  validation {
    condition     = var.image_repository_prefix == "" || endswith(var.image_repository_prefix, "/")
    error_message = "Le préfixe doit se terminer par « / »."
  }
}

variable "image_pull_secrets" {
  description = "Noms des Secrets existants pour lire un registre privé."
  type        = list(string)
  default     = []
}

variable "public_url" {
  description = "Origine publique du front. Vide : celle du fichier values de l'environnement."
  type        = string
  default     = ""
}

variable "ingress_host" {
  description = "Nom de domaine de l'ingress. Vide : pas d'ingress (accès par port-forward)."
  type        = string
  default     = ""
}

variable "release_name" {
  description = "Nom de la release Helm."
  type        = string
  default     = "microcrm"
}

variable "timeout_seconds" {
  description = "Attente maximale que les pods soient prêts, avant retour arrière."
  type        = number
  default     = 300
}
