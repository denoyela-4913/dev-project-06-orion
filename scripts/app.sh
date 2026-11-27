#!/usr/bin/env bash
# But: lancer l'application sur le poste avec Docker seul, en une commande.
# Usage: scripts/app.sh <start|stop|status|logs> [dev|staging]     (environnement par défaut: dev)
#   start   construit les images, démarre, attend que l'application réponde et affiche son adresse
#   stop    arrête les conteneurs ; les données de staging (volumes) sont conservées
# Cet environnement complet (Compose) convient à l'usage courant. Pour régler les ports ou lancer le back ou le front
# seul : scripts/run_all.sh, run_back.sh, run_front.sh. Pour Kubernetes: scripts/helm-deploy.sh. Pour développer avec
# rechargement à chaud: voir le README.
set -euo pipefail

usage() { echo "Usage: $0 <start|stop|status|logs> [dev|staging]" >&2; exit 2; }
[[ $# -ge 1 && $# -le 2 ]] || usage
action=$1
env_name=${2:-dev}
case $env_name in
  dev) url=http://localhost:4280 ;;
  staging) url=https://localhost:4443 ;;
  *) usage ;;
esac
compose="$(cd "$(dirname "$0")" && pwd)/compose.sh"

case $action in
  start)
    "$compose" "$env_name" up -d --build --wait --wait-timeout 180
    echo "Application prête : $url"
    ;;
  stop) "$compose" "$env_name" down ;;
  status) "$compose" "$env_name" ps ;;
  logs) "$compose" "$env_name" logs --follow --tail 100 ;;
  *) usage ;;
esac
