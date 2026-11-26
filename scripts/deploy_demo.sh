#!/usr/bin/env bash
# But: déploiement de démonstration des trois environnements avec Terraform sur un cluster de test (kind dans la
# CI, minikube sur un poste), puis épreuve des secours sur staging.
# Fonctionnement: pour dev, staging puis production: `terraform apply`, test de déploiement, et sur staging
# scripts/test_recovery.sh. Chaque environnement est détruit après sa vérification pour libérer le cluster.
# Usage: scripts/deploy_demo.sh <version des images> [préfixe de registre]
# Les images doivent être déjà présentes dans le cluster (ou lisibles dans le registre).
# Paramètres: KUBECONFIG, KUBE_CONTEXT (obligatoire: évite de viser par erreur un autre cluster),
# IMAGE_PULL_SECRET, RECOVERY=0 pour sauter les secours.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: KUBE_CONTEXT=<contexte> $0 <version> [préfixe]" >&2; exit 2; }
version=$1
prefix=${2:-}
context=${KUBE_CONTEXT:?KUBE_CONTEXT est obligatoire (contexte du cluster de test)}
kubeconfig=${KUBECONFIG:-$HOME/.kube/config}
here="$(cd "$(dirname "$0")" && pwd)"
state=$(mktemp -d)
trap 'rm -rf "$state"' EXIT

[[ "$(kubectl config current-context)" = "$context" ]] ||
  { echo "Le contexte courant de kubectl doit être « $context »." >&2; exit 1; }

for environment in dev staging production; do
  echo
  echo "===== Environnement $environment: version $version ====="
  directory="$here/../deploy/terraform/environments/$environment"
  variables=(-var "kubeconfig_path=$kubeconfig" -var "kube_context=$context" -var "image_tag=$version"
    -var "image_repository_prefix=$prefix")
  if [[ -n "${IMAGE_PULL_SECRET:-}" ]]; then variables+=(-var "image_pull_secrets=[\"$IMAGE_PULL_SECRET\"]"); fi

  terraform -chdir="$directory" init -input=false -lockfile=readonly -reconfigure \
    -backend-config="path=$state/$environment.tfstate" >/dev/null
  terraform -chdir="$directory" apply -input=false -auto-approve "${variables[@]}"
  "$here/verify_deployment.sh" "microcrm-$environment"

  if [[ "$environment" = staging ]] && [[ "${RECOVERY:-1}" = 1 ]]; then
    options=(--set "images.repositoryPrefix=$prefix")
    if [[ -n "${IMAGE_PULL_SECRET:-}" ]]; then options+=(--set "imagePullSecrets[0].name=$IMAGE_PULL_SECRET"); fi
    "$here/test_recovery.sh" staging "$version" "${options[@]}"
  fi

  terraform -chdir="$directory" destroy -input=false -auto-approve "${variables[@]}" >/dev/null
  echo "Environnement $environment vérifié puis supprimé."
done
