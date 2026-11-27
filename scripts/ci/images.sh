#!/usr/bin/env bash
# But: job `images` de la CI : construire les images front et back.
# Fonctionnement: avec IMAGE_ARTIFACTS, les images reprennent les produits des tests sans recompiler ; sans lui, le
# Dockerfile compile. Dans GitHub Actions, IMAGE_ARTIFACTS est exigé : un oubli ferait recompiler sans erreur, et
# l'image ne contiendrait plus le produit testé.
# Usage: scripts/ci/images.sh     ou  scripts/ci_local.sh images       (Docker requis)
# Paramètres: IMAGE_ARTIFACTS (dossier des produits), IMAGE_TAG, IMAGE_SOURCE, IMAGE_REVISION (cf. build_images.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."

if [[ -n "${IMAGE_ARTIFACTS:-}" ]]; then
  exec scripts/build_images.sh "$IMAGE_ARTIFACTS"
fi
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "ÉCHEC: IMAGE_ARTIFACTS est obligatoire dans GitHub Actions (produits des jobs de tests)" >&2
  exit 1
fi
exec scripts/build_images.sh
