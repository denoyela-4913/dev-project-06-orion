#!/usr/bin/env bash
# But: job `lint` de la CI. hadolint sur le Dockerfile, ESLint sur le front.
# Usage: scripts/ci/lint.sh     ou  scripts/ci_local.sh lint       (Docker et Node requis)
set -euo pipefail
cd "$(dirname "$0")/../.."

# hadolint depuis son image officielle, épinglée par version et digest : pas d'action tierce de plus. Le Dockerfile
# est passé sur l'entrée standard, aucun fichier du dépôt n'est monté. Toute remarque, même `info`, fait échouer.
# v2.15.1. Dependabot ne suit pas cette référence : à mettre à jour à la main.
HADOLINT=hadolint/hadolint:v2.15.1-alpine@sha256:a1d49ae1a4e83c1dbad26b8c1ad7588c8bd1e04f4866b34ad3cac50335198552
docker run --rm -i "$HADOLINT" hadolint - <Dockerfile

scripts/deps.sh install front
# `--max-warnings 0` (script "lint" de package.json) : un avertissement fait aussi échouer.
cd front
npm run lint
