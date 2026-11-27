#!/usr/bin/env bash
# But: lancer le back seul dans un conteneur Docker.
# Fonctionnement: construit l'image si elle manque, lance le conteneur en arrière-plan, attend que l'API réponde et
# affiche son adresse. Pour le front et le back ensemble : scripts/run_all.sh.
# Usage: scripts/run_back.sh [options] [-- options de `docker run`]
#   --port N          port de l'API sur le poste (défaut 8080)
#   --bind ADRESSE    interface d'écoute (défaut 127.0.0.1 ; l'API n'a pas d'authentification)
#   --name NOM        nom du conteneur (défaut microcrm-back)
#   --image IMAGE     image à lancer (défaut microcrm-back:local)
#   --build           reconstruire l'image avant de lancer
#   --cors ORIGINES   origines web autorisées, séparées par des virgules
#   --data VOLUME     conserver les données dans ce volume (par défaut : base en mémoire, données de démonstration)
#   --network RÉSEAU  rattacher le conteneur à ce réseau Docker
#   --env NOM=VALEUR  variable d'environnement (répétable)
#   --stop            arrêter et supprimer le conteneur (le volume de --data est conservé)
# Exemples: scripts/run_back.sh --port 9090 --build
#           scripts/run_back.sh --data microcrm-data -- --memory 1g
set -euo pipefail
# shellcheck source=lib_run.sh
. "$(dirname "$0")/lib_run.sh"

usage() { echo "Usage: $0 [--port N] [--bind ADRESSE] [--name NOM] [--image IMAGE] [--build] [--cors ORIGINES]" \
  "[--data VOLUME] [--network RÉSEAU] [--env NOM=VALEUR]... [--stop] [-- options docker run]" >&2; exit 2; }

port=8080
bind=127.0.0.1
name=microcrm-back
image=microcrm-back:local
build=0
stop=0
# Origines du serveur de développement Angular, du front en HTTPS et du port par défaut de run_front.sh.
cors=http://localhost:4200,https://localhost,http://localhost:4280
options=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) need_value "$1" $#; port=$2; shift 2 ;;
    --bind) need_value "$1" $#; bind=$2; shift 2 ;;
    --name) need_value "$1" $#; name=$2; shift 2 ;;
    --image) need_value "$1" $#; image=$2; shift 2 ;;
    --build) build=1; shift ;;
    --cors) need_value "$1" $#; cors=$2; shift 2 ;;
    --data)
      need_value "$1" $#
      # Mêmes réglages que le staging et la production (deploy/compose/compose.hardened.yaml).
      options+=(--volume "$2:/data"
        --env 'SPRING_DATASOURCE_URL=jdbc:hsqldb:file:/data/microcrm;shutdown=true;hsqldb.write_delay=false'
        --env SPRING_DATASOURCE_USERNAME=sa --env SPRING_JPA_HIBERNATE_DDL_AUTO=update)
      shift 2
      ;;
    --network) need_value "$1" $#; options+=(--network "$2"); shift 2 ;;
    --env) need_value "$1" $#; options+=(--env "$2"); shift 2 ;;
    --stop) stop=1; shift ;;
    --) shift; options+=("$@"); break ;;
    *) usage ;;
  esac
done
check_port "$port"

if [[ $stop == 1 ]]; then
  stop_container "$name"
  exit 0
fi
ensure_free "$name"
ensure_image "$image" back "$build"
docker run --detach --name "$name" --label "$LABEL=1" --publish "$bind:$port:8080" \
  --env "APP_CORS_ALLOWED_ORIGINS=$cors" "${options[@]}" "$image" >/dev/null
# Sonde jouée dans le conteneur, sur sa boucle locale : la même que celle de Compose, quelle que soit --bind.
wait_ready "$name" docker exec "$name" wget -q -O /dev/null http://127.0.0.1:8080/actuator/health/readiness
case $bind in
  127.0.0.1 | 0.0.0.0) address=http://localhost:$port ;;
  # Hors du poste, l'API circulerait en clair : pas de lien tout prêt, un avertissement.
  *) address="port $port de $bind (sans chiffrement ni authentification : réseau de confiance seulement)" ;;
esac
echo "Back prêt : $address  (journaux : docker logs -f $name ; arrêt : $0 --stop --name $name)"
