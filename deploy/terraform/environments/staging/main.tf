# Environnement « staging » : le socle, puis l'application.

module "platform" {
  source = "../../modules/platform"

  namespace   = "microcrm-staging"
  environment = "staging"

  # Identique à la production (scripts/check_parity.sh).
  quota = {
    pods            = 20
    requests_cpu    = "2"
    requests_memory = "3Gi"
    limits_memory   = "6Gi"
    storage         = "20Gi"
  }
}

module "microcrm" {
  source = "../../modules/microcrm"

  namespace               = module.platform.namespace
  environment             = "staging"
  image_tag               = var.image_tag
  image_repository_prefix = var.image_repository_prefix
  image_digests           = var.image_digests
  image_pull_secrets      = var.image_pull_secrets
  public_url              = var.public_url
  ingress_host            = var.ingress_host
}
