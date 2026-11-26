# Environnement « staging » : le socle, puis l'application.

module "platform" {
  source = "../../modules/platform"

  namespace   = "microcrm-staging"
  environment = "staging"

  quota = {
    pods            = 10
    requests_cpu    = "1"
    requests_memory = "2Gi"
    limits_memory   = "3Gi"
    storage         = "5Gi"
  }
}

module "microcrm" {
  source = "../../modules/microcrm"

  namespace               = module.platform.namespace
  environment             = "staging"
  image_tag               = var.image_tag
  image_repository_prefix = var.image_repository_prefix
  image_pull_secrets      = var.image_pull_secrets
  public_url              = var.public_url
  ingress_host            = var.ingress_host
}
