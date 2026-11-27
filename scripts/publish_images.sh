#!/usr/bin/env bash
# But: publier dans un registre les images d'une version, de la même façon depuis la CI et à la main
# (livraison de secours).
# Fonctionnement: pour chaque cible, l'image locale `microcrm-<cible>:<étiquette source>` est renommée
# `<préfixe>microcrm-<cible>:<version>` puis envoyée. Pas d'étiquette `latest`: une version désigne toujours le
# même contenu, donc une version déjà publiée est refusée.
# Usage: scripts/publish_images.sh <préfixe de registre> <version> [étiquette source, défaut ci]
# Exemple: scripts/publish_images.sh ghcr.io/<propriétaire>/<dépôt>/ 0.1.0
# Prérequis: `docker login` sur le registre. Paramètres: FORCE=1 pour republier une version existante (après un
# envoi interrompu).
set -euo pipefail

usage() { echo "Usage: $0 <préfixe de registre se terminant par /> <version> [étiquette source]" >&2; exit 2; }
[[ $# -ge 2 ]] || usage
prefix=$1
version=$2
source_tag=${3:-ci}
[[ $prefix == */ ]] || usage
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version SemVer attendue (X.Y.Z): $version" >&2; exit 2; }
# Les noms d'images n'acceptent pas les majuscules, que les noms de comptes GitHub peuvent contenir.
prefix=${prefix,,}

targets=(front back)
for target in "${targets[@]}"; do
  docker image inspect "microcrm-$target:$source_tag" >/dev/null 2>&1 ||
    { echo "Image locale absente: microcrm-$target:$source_tag" >&2; exit 1; }
done

if [[ "${FORCE:-0}" != 1 ]]; then
  for target in "${targets[@]}"; do
    image="${prefix}microcrm-$target:$version"
    if output=$(docker buildx imagetools inspect "$image" 2>&1); then
      echo "Déjà publiée: $image (FORCE=1 pour la remplacer)" >&2
      exit 1
    fi
    # Seule une réponse « introuvable » autorise la publication: une erreur d'accès ou de réseau ne prouve pas
    # que la version est libre.
    grep -qiE 'not found|manifest unknown|name unknown' <<<"$output" ||
      { echo "Impossible de vérifier si $image existe: $output" >&2; exit 1; }
  done
fi

for target in "${targets[@]}"; do
  image="${prefix}microcrm-$target:$version"
  docker tag "microcrm-$target:$source_tag" "$image"
  docker push --quiet "$image"
  echo "Publiée: $image"
done
