# shellcheck shell=bash
# Fonctions communes à helm-deploy.sh et ci/staging.sh : préparer minikube avec les images construites ici.
# À inclure avec `.`, pas à exécuter.

# Les scripts qui l'utilisent créent et suppriment des ressources : ils ne visent que minikube.
require_minikube() {
  command -v minikube >/dev/null || { echo "minikube est absent." >&2; return 1; }
  minikube status >/dev/null 2>&1 || { echo "minikube n'est pas démarré : lancer « minikube start »." >&2; return 1; }
  [[ "$(kubectl config current-context)" = minikube ]] ||
    { echo "Le contexte kubectl doit être « minikube » : kubectl config use-context minikube" >&2; return 1; }
}

# Étiquette tirée du contenu des images : un code modifié donne une nouvelle étiquette, donc de nouveaux pods
# (avec une étiquette fixe, Helm ne verrait aucun changement et garderait l'ancienne version).
local_image_tag() {
  local source_tag=$1 ids
  ids=$(docker image inspect --format '{{.Id}}' "microcrm-back:$source_tag" "microcrm-front:$source_tag") || return 1
  echo "local-$(sha256sum <<<"$ids" | cut -c1-12)"
}

# Copie les images `microcrm-{back,front}:<étiquette source>` dans minikube sous <étiquette cible>.
load_into_minikube() {
  local source_tag=$1 tag=$2 target
  for target in back front; do
    docker tag "microcrm-$target:$source_tag" "microcrm-$target:$tag"
    echo "Chargement de microcrm-$target:$tag dans minikube…"
    minikube image load "microcrm-$target:$tag"
  done
}
