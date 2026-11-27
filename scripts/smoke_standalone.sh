#!/usr/bin/env bash
# But: vérifier que l'image « tout en un » démarre : Caddy et le back, lancés par supervisord dans un seul
# conteneur.
# Fonctionnement: lance le conteneur avec le front en HTTP et l'API relayée par /api, passe le test de
# déploiement (scripts/smoke_test.sh), puis supprime le conteneur. En cas d'échec, affiche ses journaux.
# Usage: scripts/smoke_standalone.sh <image>     ex.: scripts/smoke_standalone.sh microcrm-standalone:ci
# Paramètres: PORT (port local, défaut 4290), SMOKE_TIMEOUT (cf. smoke_test.sh).
set -euo pipefail

[[ $# -eq 1 ]] || { echo "Usage: $0 <image>" >&2; exit 2; }
image=$1
port=${PORT:-4290}
here="$(cd "$(dirname "$0")" && pwd)"

container=$(docker run --detach --publish "127.0.0.1:$port:8081" \
  --env SITE_ADDRESS=:8081 --env API_BASE_URL=/api "$image")

finish() {
  local status=$?
  if [[ "$status" -ne 0 ]]; then docker logs --tail 100 "$container" >&2 || true; fi
  docker rm --force "$container" >/dev/null
}
trap finish EXIT

"$here/smoke_test.sh" "http://localhost:$port"
