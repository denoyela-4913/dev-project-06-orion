# Tests du module avec un fournisseur simulé : aucun cluster n'est nécessaire (`terraform test`).
mock_provider "kubernetes" {}

variables {
  namespace   = "microcrm-test"
  environment = "dev"
  quota = {
    pods            = 5
    requests_cpu    = "1"
    requests_memory = "1Gi"
    limits_memory   = "2Gi"
    storage         = "2Gi"
  }
}

run "the_namespace_enforces_the_restricted_pod_security_level" {
  command = plan

  assert {
    condition     = kubernetes_namespace_v1.this.metadata[0].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "L'espace de noms doit imposer le niveau restricted."
  }
}

run "an_unknown_environment_is_refused" {
  command = plan

  variables {
    environment = "demo"
  }

  expect_failures = [var.environment]
}

run "an_invalid_namespace_name_is_refused" {
  command = plan

  variables {
    namespace = "Microcrm_Test"
  }

  expect_failures = [var.namespace]
}
