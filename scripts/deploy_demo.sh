#!/usr/bin/env bash
# But: déploiement de démonstration d'environnements avec Terraform sur un cluster de test (kind dans la
# CI, minikube sur un poste), puis épreuve des secours sur staging.
# Fonctionnement: pour chaque environnement demandé (dev, staging puis production par défaut): `terraform apply`,
# contrôle des images déployées si leurs empreintes sont données, test de déploiement, et sur staging
# scripts/test_recovery.sh. Chaque environnement est détruit après sa vérification pour libérer le cluster.
# Usage: scripts/deploy_demo.sh <version des images> [préfixe de registre]
# Les images doivent être déjà présentes dans le cluster (ou lisibles dans le registre).
# Paramètres: KUBECONFIG, KUBE_CONTEXT (obligatoire: évite de viser par erreur un autre cluster),
# IMAGE_PULL_SECRET, RECOVERY=0 pour sauter les secours, ENVIRONMENTS (liste, défaut « dev staging production »),
# BACK_DIGEST et FRONT_DIGEST (empreintes `sha256:…`, ensemble: les pods désignent alors les images par elles).
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: KUBE_CONTEXT=<contexte> $0 <version> [préfixe]" >&2; exit 2; }
version=$1
prefix=${2:-}
context=${KUBE_CONTEXT:?KUBE_CONTEXT est obligatoire (contexte du cluster de test)}
kubeconfig=${KUBECONFIG:-$HOME/.kube/config}
here="$(cd "$(dirname "$0")" && pwd)"
read -r -a environments <<<"${ENVIRONMENTS:-dev staging production}"
back_digest=${BACK_DIGEST:-}
front_digest=${FRONT_DIGEST:-}
for environment in "${environments[@]}"; do
  [[ "$environment" =~ ^(dev|staging|production)$ ]] || { echo "Environnement inconnu: $environment" >&2; exit 2; }
done
if [[ -n "$back_digest$front_digest" ]]; then
  for digest in "$back_digest" "$front_digest"; do
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] ||
      { echo "BACK_DIGEST et FRONT_DIGEST doivent être donnés ensemble, au format sha256:…" >&2; exit 2; }
  done
fi
state=$(mktemp -d)
trap 'rm -rf "$state"' EXIT

[[ "$(kubectl config current-context)" = "$context" ]] ||
  { echo "Le contexte courant de kubectl doit être « $context »." >&2; exit 1; }

for environment in "${environments[@]}"; do
  echo
  echo "===== Environnement $environment: version $version ====="
  directory="$here/../deploy/terraform/environments/$environment"
  variables=(-var "kubeconfig_path=$kubeconfig" -var "kube_context=$context" -var "image_tag=$version"
    -var "image_repository_prefix=$prefix")
  if [[ -n "$back_digest" ]]; then
    variables+=(-var "image_digests={back=\"$back_digest\",front=\"$front_digest\"}")
  fi
  if [[ -n "${IMAGE_PULL_SECRET:-}" ]]; then variables+=(-var "image_pull_secrets=[\"$IMAGE_PULL_SECRET\"]"); fi

  terraform -chdir="$directory" init -input=false -lockfile=readonly -reconfigure \
    -backend-config="path=$state/$environment.tfstate" >/dev/null
  terraform -chdir="$directory" apply -input=false -auto-approve "${variables[@]}"
  # Preuve que l'environnement exécute les images attendues, et pas seulement la bonne étiquette.
  if [[ -n "$back_digest" ]]; then
    for component in back front; do
      expected=$back_digest
      if [[ "$component" = front ]]; then expected=$front_digest; fi
      deployed=$(kubectl -n "microcrm-$environment" get deployment "microcrm-$component" \
        -o jsonpath='{.spec.template.spec.containers[0].image}')
      [[ "$deployed" = *"@$expected" ]] ||
        { echo "ÉCHEC: $component déploie $deployed au lieu de l'empreinte $expected" >&2; exit 1; }
      echo "$environment/$component: $deployed"
    done
  fi
  "$here/verify_deployment.sh" "microcrm-$environment"

  if [[ "$environment" = staging ]] && [[ "${RECOVERY:-1}" = 1 ]]; then
    # Comme l'installation par Terraform: pas d'ingress sur le cluster de démonstration.
    options=(--set "images.repositoryPrefix=$prefix" --set ingress.enabled=false)
    if [[ -n "$back_digest" ]]; then
      options+=(--set "images.digests.back=$back_digest" --set "images.digests.front=$front_digest")
    fi
    if [[ -n "${IMAGE_PULL_SECRET:-}" ]]; then options+=(--set "imagePullSecrets[0].name=$IMAGE_PULL_SECRET"); fi
    "$here/test_recovery.sh" staging "$version" "${options[@]}"
  fi

  terraform -chdir="$directory" destroy -input=false -auto-approve "${variables[@]}" >/dev/null
  echo "Environnement $environment vérifié puis supprimé."
done
