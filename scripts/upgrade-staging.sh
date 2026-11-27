#!/usr/bin/env bash
# But: raccourci pour « helm-deploy.sh upgrade staging » (minikube).
# Fonctionnement: remplace son processus par scripts/helm-deploy.sh, qui documente le déroulement.
# Usage: scripts/upgrade-staging.sh      (aucun argument ; variable SKIP_BUILD acceptée)
set -euo pipefail
exec "$(dirname "$0")/helm-deploy.sh" upgrade staging
