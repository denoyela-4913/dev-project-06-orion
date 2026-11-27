#!/usr/bin/env bash
# But: rejouer à la main, sur le poste, les jobs de la CI (.github/workflows/ci.yml), avant de pousser.
# Fonctionnement: un job rejouable porte le nom de son script. `ci_local.sh <job>` lance scripts/ci/<job>.sh, le
# script même que le job lance dans la CI ; ce fichier ne contient aucun contrôle. Chaque script décrit le sien.
# Usage: scripts/ci_local.sh <job>...      dans l'ordre donné, arrêt au premier échec
#        scripts/ci_local.sh all           tous les jobs ci-dessous sauf `staging`
# Jobs: lint test-front test-back coverage infra-check images compose-test e2e scan staging
#   coverage : après test-front et test-back ; compose-test, e2e, scan et staging : après images.
#   images : reprend les produits des tests si test-front ET test-back ont tourné dans la même commande ; sinon le
#   Dockerfile compile, pour ne jamais reprendre un produit périmé.
# Non rejoués: sonar-* (jeton réservé à la CI), candidate, release, notify (publication et services de GitHub).
# Écarts avec la CI: les outils sont ceux du poste (ex. version de Helm), minikube remplace kind.
# Les outils nécessaires aux jobs demandés sont vérifiés avant de commencer.
set -euo pipefail

all=(lint test-front test-back coverage infra-check images compose-test e2e scan)
usage() { echo "Usage: $0 all | <${all[*]} staging>..." >&2; exit 2; }
[[ $# -ge 1 ]] || usage
steps=("$@")
if [[ "$*" = all ]]; then steps=("${all[@]}"); fi
# Tout est vérifié avant de commencer : une faute de frappe ne doit pas apparaître après dix minutes.
for step in "${steps[@]}"; do
  [[ " ${all[*]} staging " = *" $step "* ]] || usage
done

# Outils du poste par job (Docker sert presque partout ; les versions de la CI sont dans ci.yml).
tools_of() {
  case $1 in
    lint) echo docker npm ;;
    test-front | test-back | images | compose-test | e2e | scan) echo docker ;;
    coverage) echo python3 git ;;
    infra-check) echo docker helm terraform ;;
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
  echo "Outils absents pour les jobs demandés : ${missing[*]}" >&2
  exit 1
fi

scripts="$(cd "$(dirname "$0")" && pwd)/ci"
# Une valeur héritée du terminal ferait reprendre d'anciens produits.
unset IMAGE_ARTIFACTS
tested=""
for step in "${steps[@]}"; do
  echo
  echo "===== $step ====="
  if [[ $step == images && $tested == *front* && $tested == *back* ]]; then
    IMAGE_ARTIFACTS=artifacts "$scripts/$step.sh"
  else
    "$scripts/$step.sh"
  fi
  if [[ $step == test-* ]]; then tested+=" ${step#test-}"; fi
  echo "===== $step : réussi ====="
done
echo
echo "Réussi : ${steps[*]}"
