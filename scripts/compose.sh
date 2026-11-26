#!/usr/bin/env bash
# But: lancer Docker Compose avec les fichiers d'un environnement, sans les recopier à la main.
# Usage: scripts/compose.sh <dev|staging|production> <commande compose...>
# Exemples: scripts/compose.sh dev up -d --build --wait
#           scripts/compose.sh staging logs -f back
#           scripts/compose.sh dev down
# Paramètres: IMAGES (BACK_IMAGE, FRONT_IMAGE) pour lancer des images publiées au lieu de les construire.
set -euo pipefail

usage() { echo "Usage: $0 <dev|staging|production> <commande compose...>" >&2; exit 2; }
[ $# -ge 2 ] || usage
env_name=$1
shift

dir="$(cd "$(dirname "$0")/../deploy/compose" && pwd)"
case $env_name in
  dev) files=(compose.yaml compose.dev.yaml) ;;
  staging) files=(compose.yaml compose.hardened.yaml compose.staging.yaml) ;;
  production) files=(compose.yaml compose.hardened.yaml compose.production.yaml) ;;
  *) usage ;;
esac

args=()
for file in "${files[@]}"; do args+=(-f "$dir/$file"); done
# Un nom de projet par environnement : volumes et réseaux séparés.
exec docker compose -p "microcrm-$env_name" --env-file "$dir/env/$env_name.env" "${args[@]}" "$@"
