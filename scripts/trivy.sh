#!/usr/bin/env bash
# But: chercher les vulnérabilités, secrets et erreurs de configuration avec Trivy, de la même façon dans la CI,
# dans le scan hebdomadaire et sur un poste.
# Fonctionnement: lance l'image officielle de Trivy, épinglée par digest. Aucune action GitHub de Trivy n'est
# utilisée: en mars 2026, la chaîne de publication de Trivy a été compromise et des tags de ses actions ont été
# réécrits (avis GHSA-69fq-xp46-6x23). La 0.76.2 est postérieure, et sa release est immuable.
# Usage: scripts/trivy.sh repo                   dépendances (verrous), secrets et configurations du dépôt
#        scripts/trivy.sh image <nom>...         images Docker présentes sur la machine
# Échec (code 1): une vulnérabilité CRITIQUE ou HAUTE qui a un correctif, un secret, ou une erreur de
# configuration critique ou haute (critère d'acceptation du document de normalisation). Le reste est affiché.
# Paramètres: TRIVY_CACHE_DIR (cache de la base de vulnérabilités, défaut ~/.cache/orion-trivy).
set -euo pipefail

# aquasec/trivy 0.76.2 (05/11/2026). Dependabot ne suit pas cette référence: à mettre à jour à la main.
TRIVY_IMAGE="aquasec/trivy@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb"

usage() { echo "Usage: $0 repo | image <nom>..." >&2; exit 2; }
[[ $# -ge 1 ]] || usage
mode=$1
shift

root="$(cd "$(dirname "$0")/.." && pwd)"
cache="${TRIVY_CACHE_DIR:-$HOME/.cache/orion-trivy}"
mkdir -p "$cache"

trivy() { docker run --rm -v "$cache":/root/.cache/trivy "$@"; }
# Deux passes: la première affiche tout à partir de MOYENNE sans faire échouer, la seconde applique la règle.
report=(--quiet --severity "CRITICAL,HIGH,MEDIUM")
gate=(--quiet --severity "CRITICAL,HIGH" --ignore-unfixed --exit-code 1)

case $mode in
  repo)
    [[ $# -eq 0 ]] || usage
    skip="front/node_modules,front/dist,front/coverage,front/.angular,back/build,back/bin,back/.gradle,docs,learning"
    run() { trivy -v "$root":/repo:ro "$TRIVY_IMAGE" fs --scanners vuln,secret,misconfig --skip-dirs "$skip" "$@" /repo; }
    run "${report[@]}"
    run "${gate[@]}"
    ;;
  image)
    [[ $# -ge 1 ]] || usage
    failed=0
    for name in "$@"; do
      echo "=== $name"
      run() { trivy -v /var/run/docker.sock:/var/run/docker.sock "$TRIVY_IMAGE" image --scanners vuln,secret "$@" "$name"; }
      run "${report[@]}"
      run "${gate[@]}" || failed=1
    done
    exit "$failed"
    ;;
  *) usage ;;
esac
