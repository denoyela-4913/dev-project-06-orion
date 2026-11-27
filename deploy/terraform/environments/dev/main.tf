# Environnement « dev » : le socle, puis l'application.

module "platform" {
  source = "../../modules/platform"

  namespace   = "microcrm-dev"
  environment = "dev"

  quota = {
    pods            = 6
    requests_cpu    = "500m"
    requests_memory = "1Gi"
    limits_memory   = "2Gi"
    storage         = "2Gi"
  }
}

module "microcrm" {
  source = "../../modules/microcrm"

  namespace               = module.platform.namespace
  environment             = "dev"
  image_tag               = var.image_tag
  image_repository_prefix = var.image_repository_prefix
  image_digests           = var.image_digests
  image_pull_secrets      = var.image_pull_secrets
  public_url              = var.public_url
  ingress_host            = var.ingress_host
}
