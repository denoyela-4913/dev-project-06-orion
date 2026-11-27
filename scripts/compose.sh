#!/usr/bin/env bash
# But: lancer Docker Compose avec les fichiers d'un environnement, sans les recopier à la main.
# Usage: scripts/compose.sh <dev|staging|production> <commande compose...>
# Exemples: scripts/compose.sh dev up -d --build --wait
#           scripts/compose.sh staging logs -f back
#           scripts/compose.sh dev down
# Paramètres: IMAGES (BACK_IMAGE, FRONT_IMAGE) pour lancer des images publiées au lieu de les construire.
set -euo pipefail

usage() { echo "Usage: $0 <dev|staging|production> <commande compose...>" >&2; exit 2; }
[[ $# -ge 2 ]] || usage
env_name=$1
shift

dir="$(cd "$(dirname "$0")/../deploy/compose" && pwd)"
case $env_name in
  dev) files=(compose.yaml compose.dev.yaml) ;;
  # Mêmes fichiers pour les deux : seul le fichier env diffère.
  staging | production) files=(compose.yaml compose.hardened.yaml) ;;
  *) usage ;;
esac

args=()
for file in "${files[@]}"; do args+=(-f "$dir/$file"); done
# Un nom de projet par environnement : volumes et réseaux séparés.
# COMPOSE_ENV_FILE et COMPOSE_PROJECT: réservés à scripts/check_parity.sh, qui compare deux environnements à
# valeurs égales.
exec docker compose -p "${COMPOSE_PROJECT:-microcrm-$env_name}" \
  --env-file "${COMPOSE_ENV_FILE:-$dir/env/$env_name.env}" "${args[@]}" "$@"
