#!/usr/bin/env bash
# But: lancer les tests de bout en bout (Playwright, Chromium) contre une application déjà démarrée.
# Fonctionnement: utilise l'image officielle de Playwright, épinglée par digest, qui contient le navigateur et
# ses bibliothèques: rien à installer sur la machine hôte, et le même navigateur partout. La version de l'image
# doit être celle de @playwright/test (e2e/package.json).
# Usage: scripts/e2e.sh [URL du front, défaut http://localhost:4280]
# Exemple: scripts/compose.sh dev up -d --build --wait && scripts/e2e.sh
set -euo pipefail

# playwright v1.65.1 (13/11/2026). Dependabot ne suit pas cette référence : à mettre à jour avec e2e/package.json.
PLAYWRIGHT_IMAGE="mcr.microsoft.com/playwright:v1.65.1-noble@sha256:1507cbfc550a63a6b7396791ca4f00df17beb56342d2447b3f106c306f525579"
base=${1:-http://localhost:4280}
root="$(cd "$(dirname "$0")/.." && pwd)"

# `--network host`: l'adresse donnée est vue du conteneur comme depuis la machine. Les fichiers produits
# (rapport, traces) appartiennent à l'utilisateur courant.
docker run --rm --network host --ipc host --user "$(id -u):$(id -g)" \
  -v "$root/e2e":/e2e -w /e2e -e HOME=/tmp -e CI="${CI:-}" -e E2E_BASE_URL="$base" \
  "$PLAYWRIGHT_IMAGE" sh -c 'npm ci --ignore-scripts --no-audit --no-fund && npx playwright test'
