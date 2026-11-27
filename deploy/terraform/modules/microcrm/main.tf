# La release Helm de l'application. Le chart est celui du dépôt : même gabarits que scripts/deploy.sh.

locals {
  chart = "${path.module}/../../../helm/microcrm"

  # Seules les valeurs fournies remplacent celles du fichier de l'environnement.
  overrides = merge(
    {
      images = {
        repositoryPrefix = var.image_repository_prefix
        tag              = var.image_tag
        digests          = var.image_digests
      }
      imagePullSecrets = [for name in var.image_pull_secrets : { name = name }]
      ingress = merge(
        { enabled = var.ingress_host != "" },
        var.ingress_host != "" ? { host = var.ingress_host } : {},
      )
    },
    var.public_url != "" ? { publicUrl = var.public_url } : {},
  )
}

resource "helm_release" "microcrm" {
  name      = var.release_name
  namespace = var.namespace
  chart     = local.chart

  # Même ordre que scripts/deploy.sh : réglages partagés par staging et production, puis ceux de l'environnement.
  values = concat(
    var.environment == "dev" ? [] : [file("${local.chart}/values-prodlike.yaml")],
    [
      file("${local.chart}/values-${var.environment}.yaml"),
      yamlencode(local.overrides),
    ],
  )

  # Attend que les pods soient prêts ; sinon, annule (retour à la révision précédente).
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = var.timeout_seconds
  max_history     = 10
}
