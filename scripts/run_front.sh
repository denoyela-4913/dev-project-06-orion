#!/usr/bin/env bash
# But: lancer le front seul (Caddy) dans un conteneur Docker.
# Fonctionnement: construit l'image si elle manque, lance le conteneur en arrière-plan, attend que le front réponde
# et affiche son adresse. Pour le front et le back ensemble : scripts/run_all.sh.
# Usage: scripts/run_front.sh [options] [-- options de `docker run`]
#   --port N            port du front sur le poste (défaut 4280)
#   --bind ADRESSE      interface d'écoute (défaut 127.0.0.1)
#   --name NOM          nom du conteneur (défaut microcrm-front)
#   --image IMAGE       image à lancer (défaut microcrm-front:local)
#   --build             reconstruire l'image avant de lancer
#   --https             servir en HTTPS (certificat interne de Caddy) au lieu de HTTP
#   --api-url URL       adresse de l'API vue par le navigateur (défaut http://localhost:8080) ; l'origine du front
#                       doit alors figurer dans les origines autorisées du back (run_back.sh --cors)
#   --upstream HÔTE:PORT  relayer /api vers ce back (même origine) ; remplace --api-url
#   --network RÉSEAU    rattacher le conteneur à ce réseau Docker
#   --env NOM=VALEUR    variable d'environnement (répétable)
#   --stop              arrêter et supprimer le conteneur
# Exemples: scripts/run_front.sh --port 8081 --api-url http://localhost:9090
#           scripts/run_front.sh --https --port 8443
set -euo pipefail
# shellcheck source=lib_run.sh
. "$(dirname "$0")/lib_run.sh"

usage() { echo "Usage: $0 [--port N] [--bind ADRESSE] [--name NOM] [--image IMAGE] [--build] [--https]" \
  "[--api-url URL | --upstream HÔTE:PORT] [--network RÉSEAU] [--env NOM=VALEUR]... [--stop]" \
  "[-- options docker run]" >&2; exit 2; }

port=4280
bind=127.0.0.1
name=microcrm-front
image=microcrm-front:local
build=0
stop=0
https=0
api_url=""
upstream=""
options=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) need_value "$1" $#; port=$2; shift 2 ;;
    --bind) need_value "$1" $#; bind=$2; shift 2 ;;
    --name) need_value "$1" $#; name=$2; shift 2 ;;
    --image) need_value "$1" $#; image=$2; shift 2 ;;
    --build) build=1; shift ;;
    --https) https=1; shift ;;
    --api-url) need_value "$1" $#; api_url=$2; shift 2 ;;
    --upstream) need_value "$1" $#; upstream=$2; shift 2 ;;
    --network) need_value "$1" $#; options+=(--network "$2"); shift 2 ;;
    --env) need_value "$1" $#; options+=(--env "$2"); shift 2 ;;
    --stop) stop=1; shift ;;
    --) shift; options+=("$@"); break ;;
    *) usage ;;
  esac
done
check_port "$port"
[[ -z $api_url || -z $upstream ]] || { echo "--api-url et --upstream s'excluent" >&2; usage; }

if [[ $stop == 1 ]]; then
  stop_container "$name"
  exit 0
fi
ensure_free "$name"
ensure_image "$image" front "$build"

if [[ $https == 1 ]]; then
  # Caddy sert le nom `localhost` en HTTPS sur le port 443 du conteneur.
  site=localhost container_port=443 scheme=https
else
  site=:8080 container_port=8080 scheme=http
fi
environment=(--env "SITE_ADDRESS=$site")
if [[ -n $upstream ]]; then
  environment+=(--env API_BASE_URL=/api --env "API_UPSTREAM=$upstream")
else
  environment+=(--env "API_BASE_URL=${api_url:-http://localhost:8080}")
fi

docker run --detach --name "$name" --label "$LABEL=1" --publish "$bind:$port:$container_port" \
  "${environment[@]}" "${options[@]}" "$image" >/dev/null
host=$(local_host "$bind")
# En HTTPS, le certificat porte le nom `localhost` : c'est par ce nom qu'il faut joindre le front.
if [[ $https == 1 && $host == 127.0.0.1 ]]; then host=localhost; fi
url="$scheme://$host:$port"
# `--insecure` : en HTTPS local, le certificat vient de l'autorité interne de Caddy.
wait_ready "$name" curl --fail --silent --insecure --max-time 3 --output /dev/null "$url/healthz"
echo "Front prêt : $url  (journaux : docker logs -f $name ; arrêt : $0 --stop --name $name)"
