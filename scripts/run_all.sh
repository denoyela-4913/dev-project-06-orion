#!/usr/bin/env bash
# But: lancer le back et le front ensemble dans deux conteneurs Docker.
# Fonctionnement: crée un réseau Docker, lance le back (run_back.sh) puis le front (run_front.sh), qui relaie /api
# vers lui : le navigateur ne voit qu'une adresse. Si le front ne démarre pas, le back est arrêté aussi.
# Pour les réglages complets de dev ou de staging, avec Docker Compose : cf. scripts/compose.sh.
# Usage: scripts/run_all.sh [options]
#   --front-port N    port du front sur le poste (défaut 4280)
#   --back-port N     port de l'API sur le poste (défaut 8080)
#   --bind ADRESSE    interface d'écoute du front (défaut 127.0.0.1) ; l'API reste sur 127.0.0.1
#   --name PRÉFIXE    préfixe des conteneurs et du réseau (défaut microcrm)
#   --front-image IMAGE, --back-image IMAGE
#   --build           reconstruire les images avant de lancer
#   --https           front en HTTPS (certificat interne de Caddy)
#   --data VOLUME     conserver les données dans ce volume
#   --stop            arrêter les deux conteneurs et supprimer le réseau (le volume est conservé)
# Exemple: scripts/run_all.sh --front-port 5000 --back-port 5001 --build
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib_run.sh
. "$here/lib_run.sh"

usage() { echo "Usage: $0 [--front-port N] [--back-port N] [--bind ADRESSE] [--name PRÉFIXE] [--front-image IMAGE]" \
  "[--back-image IMAGE] [--build] [--https] [--data VOLUME] [--stop]" >&2; exit 2; }

front_port=4280
back_port=8080
prefix=microcrm
stop=0
front=()
back=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --front-port) need_value "$1" $#; front_port=$2; shift 2 ;;
    --back-port) need_value "$1" $#; back_port=$2; shift 2 ;;
    --bind) need_value "$1" $#; front+=(--bind "$2"); shift 2 ;;
    --name) need_value "$1" $#; prefix=$2; shift 2 ;;
    --front-image) need_value "$1" $#; front+=(--image "$2"); shift 2 ;;
    --back-image) need_value "$1" $#; back+=(--image "$2"); shift 2 ;;
    --build) front+=(--build); back+=(--build); shift ;;
    --https) front+=(--https); shift ;;
    --data) need_value "$1" $#; back+=(--data "$2"); shift 2 ;;
    --stop) stop=1; shift ;;
    *) usage ;;
  esac
done
check_port "$front_port"
check_port "$back_port"
[[ $front_port != "$back_port" ]] || { echo "Les deux ports doivent être différents" >&2; exit 2; }

network="$prefix-run"
if [[ $stop == 1 ]]; then
  stop_container "$prefix-front"
  stop_container "$prefix-back"
  if docker network inspect "$network" >/dev/null 2>&1; then docker network rm "$network" >/dev/null; fi
  exit 0
fi
# Les deux noms sont vérifiés avant de lancer quoi que ce soit.
ensure_free "$prefix-back"
ensure_free "$prefix-front"
docker network inspect "$network" >/dev/null 2>&1 || docker network create "$network" >/dev/null

"$here/run_back.sh" --name "$prefix-back" --port "$back_port" --network "$network" "${back[@]}"
if ! "$here/run_front.sh" --name "$prefix-front" --port "$front_port" --network "$network" \
  --upstream "$prefix-back:8080" "${front[@]}"; then
  stop_container "$prefix-back" >&2
  docker network rm "$network" >/dev/null
  fail "le front n'a pas démarré"
fi
echo "Arrêt des deux : $0 --stop --name $prefix"
