variable "kubeconfig_path" {
  description = "Fichier kubeconfig du cluster visé."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte kubectl à utiliser. null : le contexte courant du fichier."
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Version des images à déployer (obligatoire)."
  type        = string
}

variable "image_digests" {
  description = "Empreintes sha256 des images (images-digests.env d'une release). Vides : désignées par image_tag."
  type = object({
    back  = string
    front = string
  })
  default = { back = "", front = "" }
}

variable "image_repository_prefix" {
  description = "Préfixe du registre avec le « / » final. Vide : images déjà présentes dans le cluster."
  type        = string
  default     = ""
}

variable "image_pull_secrets" {
  description = "Secrets existants pour lire un registre privé."
  type        = list(string)
  default     = []
}

variable "public_url" {
  description = "Origine publique du front. Vide : valeur du chart pour l'environnement."
  type        = string
  default     = ""
}

variable "ingress_host" {
  description = "Domaine servi par l'ingress. Vide : pas d'ingress."
  type        = string
  default     = ""
}
