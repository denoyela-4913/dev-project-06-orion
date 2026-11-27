#!/usr/bin/env bash
# But: job `compose-test` de la CI : déployer les images avec Docker Compose dans les trois environnements et vérifier
# santé, application, API à travers le front et écriture avec l'origine du navigateur (scripts/smoke_test.sh).
# Usage: scripts/ci/compose-test.sh     ou  scripts/ci_local.sh images compose-test       (Docker requis ; les ports
# 80, 443, 4280, 4443 et 8080 doivent être libres)
# Paramètres: BACK_IMAGE, FRONT_IMAGE (défaut microcrm-<partie>:ci).
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib_ci.sh
. scripts/lib_ci.sh

title "Environnement dev"
compose_up dev
scripts/smoke_test.sh http://localhost:4280
compose_down
end

# Staging et production en HTTPS, avec le certificat interne.
title "Environnement staging"
compose_up staging
SMOKE_INSECURE=1 scripts/smoke_test.sh https://localhost:4443
compose_down
end

title "Environnement production"
compose_up production
SMOKE_INSECURE=1 scripts/smoke_test.sh https://localhost
compose_down
end
