#!/usr/bin/env bash
# But: fonctions communes à run_back.sh, run_front.sh et run_all.sh (à inclure, pas à lancer).
# Les conteneurs portent le label LABEL : --stop refuse d'arrêter un conteneur que ces scripts n'ont pas lancé.

LABEL=microcrm.run

fail() { echo "ÉCHEC: $*" >&2; exit 1; }

# need_value <option> <nombre d'arguments restants> : une option qui attend une valeur ne doit pas être la dernière.
need_value() { [[ $2 -ge 2 ]] || { echo "Valeur manquante après $1" >&2; usage; }; }

check_port() {
  if [[ ! $1 =~ ^[0-9]{1,5}$ ]] || ((10#$1 < 1 || 10#$1 > 65535)); then
    echo "Port invalide: $1" >&2
    exit 2
  fi
}

exists() { docker container inspect "$1" >/dev/null 2>&1; }

# ensure_image <image> <cible du Dockerfile> <1 pour reconstruire> : construit l'image si elle manque.
ensure_image() {
  if [[ $3 == 1 ]] || ! docker image inspect "$1" >/dev/null 2>&1; then
    docker build --target "$2" --tag "$1" "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
}

# Pas de remplacement silencieux : un conteneur du même nom peut tenir des données ou des réglages différents.
ensure_free() {
  if exists "$1"; then fail "le conteneur $1 existe déjà : l'arrêter avec --stop, ou choisir un autre --name"; fi
}

stop_container() {
  if ! exists "$1"; then
    echo "Aucun conteneur $1"
    return 0
  fi
  [[ $(docker container inspect --format "{{index .Config.Labels \"$LABEL\"}}" "$1") == 1 ]] ||
    fail "$1 n'a pas été lancé par ces scripts : il n'est pas touché"
  docker rm --force "$1" >/dev/null
  echo "Arrêté: $1"
}

# wait_ready <conteneur> <commande de sonde...> : attend que la sonde réussisse ; sinon affiche les journaux et
# supprime le conteneur.
# Paramètre: RUN_TIMEOUT (secondes, défaut 120).
wait_ready() {
  local name=$1 deadline=$((SECONDS + ${RUN_TIMEOUT:-120}))
  shift
  until "$@" >/dev/null 2>&1; do
    if [[ $(docker container inspect --format '{{.State.Running}}' "$name") != true ]] || ((SECONDS >= deadline)); then
      docker logs --tail 50 "$name" >&2 || true
      docker rm --force "$name" >/dev/null
      fail "$name ne répond pas (conteneur supprimé, derniers journaux ci-dessus)"
    fi
    sleep 1
  done
}

# Adresse à interroger depuis le poste : une écoute sur toutes les interfaces se joint par la boucle locale.
local_host() { if [[ $1 == 0.0.0.0 ]]; then echo localhost; else echo "$1"; fi; }
