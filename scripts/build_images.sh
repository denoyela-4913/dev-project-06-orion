#!/usr/bin/env bash
# But: construire les images front et back, de la même façon dans la CI et sur un poste.
# Fonctionnement:
#   sans paramètre : les étapes de compilation du Dockerfile produisent le front et le JAR ;
#   avec un dossier : les images reprennent les produits de <dossier>/front et <dossier>/back (artefacts des jobs
#   de tests), sans rien recompiler. Le script échoue si un produit manque ou si une compilation a lieu quand même.
# Usage: scripts/build_images.sh [dossier des artefacts]
# Paramètres: IMAGE_TAG (étiquette, défaut ci) ; IMAGE_SOURCE et IMAGE_REVISION (labels OCI, facultatifs).
set -euo pipefail

usage() { echo "Usage: $0 [dossier des artefacts]" >&2; exit 2; }
fail() { echo "ÉCHEC: $*" >&2; exit 1; }
[[ $# -le 1 ]] || usage
artifacts=""
if [[ $# -eq 1 ]]; then
  [[ -d $1 ]] || fail "dossier d'artefacts absent : $1"
  artifacts="$(cd "$1" && pwd)"
  # Contrôlé avant de construire : un dossier vide donnerait une image sans application.
  [[ -s $artifacts/front/index.html ]] || fail "front compilé absent : $artifacts/front/index.html"
  [[ -s $artifacts/back/microcrm-0.0.1-SNAPSHOT.jar ]] || fail "JAR absent dans $artifacts/back"
fi
tag=${IMAGE_TAG:-ci}

cd "$(dirname "$0")/.."
labels=()
if [[ -n "${IMAGE_SOURCE:-}" ]]; then labels+=(--label "org.opencontainers.image.source=$IMAGE_SOURCE"); fi
if [[ -n "${IMAGE_REVISION:-}" ]]; then labels+=(--label "org.opencontainers.image.revision=$IMAGE_REVISION"); fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT
for target in front back; do
  options=(--target "$target" --tag "microcrm-$target:$tag" "${labels[@]}")
  if [[ -n "$artifacts" ]]; then
    options+=(--build-context "$target-dist=$artifacts/$target")
  fi
  docker build --progress=plain "${options[@]}" . 2>&1 | tee "$log"
  # Garde-fou : un nom d'étape qui ne correspondrait plus ferait recompiler sans aucune erreur.
  if [[ -n "$artifacts" ]] && grep -q "\[$target-build " "$log"; then
    fail "l'image $target a recompilé au lieu de reprendre l'artefact"
  fi
done
