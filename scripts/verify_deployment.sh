#!/usr/bin/env bash
# But: lancer le test de déploiement (santé HTTP) sur une release installée dans un cluster, sans ingress.
# Fonctionnement: ouvre un port-forward vers le service du front, lance scripts/smoke_test.sh, ferme le tout.
# Usage: scripts/verify_deployment.sh <espace de noms> [release]
# Paramètres: LOCAL_PORT (défaut 18080), SMOKE_TIMEOUT (cf. smoke_test.sh).
set -euo pipefail

[ $# -ge 1 ] || { echo "Usage: $0 <espace de noms> [release]" >&2; exit 2; }
namespace=$1
release=${2:-microcrm}
port=${LOCAL_PORT:-18080}
here="$(cd "$(dirname "$0")" && pwd)"

kubectl -n "$namespace" port-forward "service/$release-front" "$port:80" >/dev/null &
forward=$!
trap 'kill "$forward" 2>/dev/null || true' EXIT

"$here/smoke_test.sh" "http://localhost:$port"
