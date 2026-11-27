#!/usr/bin/env bash
# But: job `scan` de la CI : Trivy sur le dépôt (dépendances, secrets, configurations) et sur les images construites.
# Bloquant sur une vulnérabilité critique ou haute qui a un correctif. Les images sont scannées même si le scan du
# dépôt a échoué : les deux résultats sont lus dans le même run. Un seul job : la base de vulnérabilités n'est
# téléchargée qu'une fois.
# Usage: scripts/ci/scan.sh     ou  scripts/ci_local.sh images scan       (Docker requis)
set -euo pipefail
cd "$(dirname "$0")/../.."

status=0
scripts/trivy.sh repo || status=1
scripts/trivy.sh image microcrm-front:ci microcrm-back:ci || status=1
exit "$status"
