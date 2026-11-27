#!/usr/bin/env bash
# But: job `staging` de la CI : déployer dev puis staging avec Terraform et le chart Helm, vérifier chacun, puis
# éprouver les secours sur staging (scripts/deploy_demo.sh).
# Fonctionnement:
#   - PLANNED=true (une version est prévue) : le cluster tire les images candidates sur GHCR par leur empreinte ;
#   - sinon : les images locales microcrm-<partie>:ci sont chargées dans le cluster.
# Dans GitHub Actions, la version déployée est écrite dans GITHUB_OUTPUT avant le déploiement : la notification la
# connaît même après un échec.
# Usage: scripts/ci_local.sh images staging       (minikube démarré ; Docker, Helm, Terraform, kubectl, Python 3)
# Paramètres: STAGING_CLUSTER (minikube par défaut, ou kind pour la CI) ; PLANNED, PLANNED_VERSION, BACK_DIGEST,
# FRONT_DIGEST (fournis par le job `candidate`).
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib_minikube.sh
. scripts/lib_minikube.sh

cluster=${STAGING_CLUSTER:-minikube}
case $cluster in
  kind) context=kind-orion ;;
  minikube) context=minikube ;;
  *) echo "STAGING_CLUSTER inconnu : $cluster (minikube ou kind)" >&2; exit 2 ;;
esac

if [[ $cluster == minikube ]]; then
  require_minikube
  # Terraform crée puis détruit ces espaces de noms : une installation existante ne doit pas être touchée.
  for namespace in microcrm-dev microcrm-staging; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
      echo "L'espace de noms $namespace existe déjà. S'il ne contient rien à garder :" >&2
      echo "  kubectl delete namespace $namespace   (efface aussi ses données)" >&2
      exit 1
    fi
  done
fi

prefix=""
if [[ "${PLANNED:-}" == true ]]; then
  # Rien à charger : le cluster tire les images candidates (publiques), comme le ferait un cluster de production.
  version=${PLANNED_VERSION:?PLANNED_VERSION est obligatoire avec PLANNED=true}
  repository=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY est obligatoire avec PLANNED=true}
  prefix="ghcr.io/${repository,,}/"
elif [[ $cluster == kind ]]; then
  revision=${GITHUB_SHA:?GITHUB_SHA est obligatoire avec kind}
  version="ci-${revision::12}"
  for target in front back; do
    docker tag "microcrm-$target:ci" "microcrm-$target:$version"
  done
  kind load docker-image --name orion "microcrm-front:$version" "microcrm-back:$version"
else
  version=$(local_image_tag ci)
  load_into_minikube ci "$version"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "version=$version" >>"$GITHUB_OUTPUT"; fi

state_on_failure() {
  local status=$?
  if [[ $status -ne 0 ]]; then
    echo "--- État du cluster après l'échec"
    kubectl get all,pvc -A || true
    kubectl get events -A --sort-by=.lastTimestamp | tail -40 || true
  fi
}
trap state_on_failure EXIT

ENVIRONMENTS="dev staging" KUBE_CONTEXT=$context scripts/deploy_demo.sh "$version" "$prefix"
