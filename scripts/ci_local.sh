#!/usr/bin/env bash
# But: rejouer à la main, sur le poste, les contrôles de la CI (.github/workflows/ci.yml), avant de pousser.
# Usage: scripts/ci_local.sh <étape>...      les étapes s'exécutent dans l'ordre donné, arrêt au premier échec
#        scripts/ci_local.sh all             toutes les étapes sauf `staging`
# Étapes (job de la CI):
#   lint      ESLint et hadolint (lint)
#   test      tests du front et du back dans l'étape de compilation du Dockerfile, avec Checkstyle et SpotBugs
#             (test-front, test-back) ; ni Node ni JDK du poste ne sont utilisés
#   coverage  seuils de 80 %, après `test` (coverage)
#   infra     chart Helm, parité, ShellCheck et Terraform (infra-check)
#   images    les images front et back (images) : à partir des produits de `test` s'il a tourné dans la même
#             commande ; sinon le Dockerfile les compile, pour ne jamais reprendre un produit périmé
#   compose   test de déploiement des trois environnements, après `images` (compose-test)
#   e2e       tests de bout en bout, après `images` (e2e)
#   scan      Trivy sur le dépôt et les images, après `images` (scan)
#   staging   dev et staging avec Terraform sur minikube, secours compris, après `images` (staging)
# Non rejoués: les analyses Sonar (jeton réservé à la CI) et la publication (candidate, release, production).
# Écarts avec la CI: les outils sont ceux du poste (ex. version de Helm), minikube remplace kind.
# Les essais Compose utilisent des projets « ci-<env> » : vos conteneurs et volumes locaux ne sont pas touchés,
# mais les ports doivent être libres (`scripts/app.sh stop` avant), dont 80 et 443 pour la production.
# Les outils nécessaires aux étapes demandées sont vérifiés avant de commencer.
set -euo pipefail

all=(lint test coverage infra images compose e2e scan)
usage() { echo "Usage: $0 all | <${all[*]} staging>..." >&2; exit 2; }
[[ $# -ge 1 ]] || usage
steps=("$@")
if [[ "$*" = all ]]; then steps=("${all[@]}"); fi
# Tout est vérifié avant de commencer : une faute de frappe ne doit pas apparaître après dix minutes.
for step in "${steps[@]}"; do
  [[ " ${all[*]} staging " = *" $step "* ]] || usage
done

# Outils du poste par étape (Docker sert presque partout ; les versions de la CI sont dans ci.yml).
tools_of() {
  case $1 in
    lint) echo docker npm ;;
    test | images | compose | e2e | scan) echo docker ;;
    coverage) echo python3 git ;;
    infra) echo docker helm terraform ;;
    staging) echo docker helm terraform kubectl minikube python3 ;;
  esac
}
missing=()
for step in "${steps[@]}"; do
  for tool in $(tools_of "$step"); do
    if ! command -v "$tool" >/dev/null && [[ " ${missing[*]} " != *" $tool "* ]]; then missing+=("$tool"); fi
  done
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Outils absents pour les étapes demandées : ${missing[*]}" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# shellcheck source=lib_minikube.sh
. scripts/lib_minikube.sh

# Projet Compose en cours d'essai, supprimé à la sortie même en cas d'échec.
running=""
cleanup() {
  if [[ -n "$running" ]]; then
    COMPOSE_PROJECT="ci-$running" scripts/compose.sh "$running" down -v >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

compose_up() {
  running=$1
  COMPOSE_PROJECT="ci-$1" BACK_IMAGE=microcrm-back:ci FRONT_IMAGE=microcrm-front:ci \
    scripts/compose.sh "$1" up -d --no-build --wait --wait-timeout 180
}
compose_down() {
  COMPOSE_PROJECT="ci-$running" scripts/compose.sh "$running" down -v
  running=""
}

step_lint() {
  local image
  # Image lue dans le workflow : une seule version à mettre à jour.
  image=$(sed -n 's/^ *HADOLINT: \([^ ]*\).*/\1/p' .github/workflows/ci.yml)
  docker run --rm -i "$image" hadolint - <Dockerfile
  scripts/deps.sh install front
  (cd front && npm run lint)
}

tested=0
step_test() {
  scripts/ci_test.sh front
  scripts/ci_test.sh back
  tested=1
}

step_coverage() {
  python3 -m unittest discover -s scripts
  python3 scripts/coverage_gate.py --base origin/main --blocking
}

step_infra() {
  local chart=deploy/helm/microcrm environment values
  for environment in dev staging production; do
    values=()
    if [[ "$environment" != dev ]]; then values+=(--values "$chart/values-prodlike.yaml"); fi
    values+=(--values "$chart/values-$environment.yaml")
    helm lint "$chart" --strict "${values[@]}"
    helm template microcrm "$chart" "${values[@]}" >/dev/null
  done
  scripts/check_parity.sh
  if helm template microcrm "$chart" --set back.replicas=2 >/dev/null 2>&1; then
    echo "Le chart devrait refuser back.replicas=2" >&2
    return 1
  fi
  if helm template microcrm "$chart" --set images.digests.back=latest >/dev/null 2>&1; then
    echo "Le chart devrait refuser une empreinte invalide" >&2
    return 1
  fi
  scripts/lint_scripts.sh
  terraform fmt -check -recursive -diff deploy/terraform
  for environment in dev staging production; do
    terraform -chdir="deploy/terraform/environments/$environment" init -backend=false -input=false -lockfile=readonly
    terraform -chdir="deploy/terraform/environments/$environment" validate
  done
  terraform -chdir=deploy/terraform/modules/platform init -backend=false -input=false
  terraform -chdir=deploy/terraform/modules/platform test
}

step_images() {
  if [[ $tested == 1 ]]; then
    scripts/build_images.sh artifacts
  else
    scripts/build_images.sh
  fi
}

step_compose() {
  compose_up dev
  scripts/smoke_test.sh http://localhost:4280
  compose_down
  compose_up staging
  SMOKE_INSECURE=1 scripts/smoke_test.sh https://localhost:4443
  compose_down
  compose_up production
  SMOKE_INSECURE=1 scripts/smoke_test.sh https://localhost
  compose_down
}

step_e2e() {
  compose_up dev
  scripts/e2e.sh http://localhost:4280
  compose_down
}

step_scan() {
  scripts/trivy.sh repo
  scripts/trivy.sh image microcrm-front:ci microcrm-back:ci
}

step_staging() {
  local namespace tag
  require_minikube
  # Terraform crée puis détruit ces espaces de noms : une installation existante ne doit pas être touchée.
  for namespace in microcrm-dev microcrm-staging; do
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
      echo "L'espace de noms $namespace existe déjà. S'il ne contient rien à garder :" >&2
      echo "  kubectl delete namespace $namespace   (efface aussi ses données)" >&2
      return 1
    fi
  done
  tag=$(local_image_tag ci)
  load_into_minikube ci "$tag"
  ENVIRONMENTS="dev staging" KUBE_CONTEXT=minikube scripts/deploy_demo.sh "$tag"
}

for step in "${steps[@]}"; do
  echo
  echo "===== $step ====="
  # Appel direct, hors `if` et `||` : sinon `set -e` serait ignoré à l'intérieur de l'étape.
  "step_$step"
  echo "===== $step : réussi ====="
done
echo
echo "Réussi : ${steps[*]}"
