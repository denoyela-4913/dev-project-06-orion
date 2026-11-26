#!/usr/bin/env bash
# But: revenir à la version précédente d'une release Helm et vérifier qu'elle répond.
# Usage: scripts/rollback.sh <espace de noms> [release] [révision]
# Sans révision, Helm revient à la précédente. `helm history <release> -n <espace>` liste les révisions.
# Les données ne sont pas modifiées par un retour arrière: pour les restaurer, scripts/restore.sh.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: $0 <espace de noms> [release] [révision]" >&2; exit 2; }
namespace=$1
release=${2:-microcrm}
revision=${3:-0}
here="$(cd "$(dirname "$0")" && pwd)"

echo "Retour arrière de « $release » ($namespace), révision ${revision/#0/précédente}"
helm rollback "$release" "$revision" -n "$namespace" --wait --timeout "${DEPLOY_TIMEOUT:-5m}"
"$here/verify_deployment.sh" "$namespace" "$release"
echo "Retour arrière réussi et vérifié."
