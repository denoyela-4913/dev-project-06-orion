#!/usr/bin/env bash
# But: job `e2e` de la CI : un vrai navigateur parcourt l'application construite, lancée avec Compose (création,
# modification, suppression, liens, saisie refusée, API indisponible ; e2e/tests/).
# Fonctionnement: lance l'environnement dev puis scripts/e2e.sh, l'outil Playwright.
# Usage: scripts/ci/e2e.sh     ou  scripts/ci_local.sh images e2e       (Docker requis)
# Paramètres: BACK_IMAGE, FRONT_IMAGE (défaut microcrm-<partie>:ci).
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib_ci.sh
. scripts/lib_ci.sh

compose_up dev
scripts/e2e.sh http://localhost:4280
compose_down
