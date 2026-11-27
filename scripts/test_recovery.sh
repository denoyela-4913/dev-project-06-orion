#!/usr/bin/env bash
# But: éprouver les secours sur une release installée avec des données conservées (environnement de test
# seulement: le script modifie les données et provoque des déploiements en échec).
# Fonctionnement, chaque étape devant réussir:
#   1. sauvegarde, modification des données, restauration: les données reviennent à l'état sauvegardé;
#   2. version dont l'image n'existe pas: Helm l'annule, le service reste en place;
#   3. version dont les pods démarrent mais qui échoue au test de déploiement: retour arrière par rollback.sh.
# Usage: scripts/test_recovery.sh <staging|production> <version installée> [options helm de l'installation...]
# Paramètres: NAMESPACE (défaut microcrm-<env>), LOCAL_PORT (défaut 18080).
set -euo pipefail

[[ $# -ge 2 ]] || { echo "Usage: $0 <staging|production> <version> [options helm...]" >&2; exit 2; }
env_name=$1
version=$2
shift 2
namespace=${NAMESPACE:-microcrm-$env_name}
port=${LOCAL_PORT:-18080}
here="$(cd "$(dirname "$0")" && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

step() { echo; echo "== $*"; }
fail() { echo "ÉCHEC: $*" >&2; exit 1; }

# Appelle l'API à travers un port-forward ouvert le temps de la commande.
api() {
  local forward status=0
  kubectl -n "$namespace" port-forward service/microcrm-front "$port:80" >/dev/null &
  forward=$!
  curl -sf --retry 20 --retry-delay 1 --retry-all-errors --max-time 10 "http://localhost:$port/healthz" >/dev/null &&
    curl -sf --max-time 10 "$@" || status=$?
  kill "$forward" 2>/dev/null || true
  wait "$forward" 2>/dev/null || true
  return "$status"
}
add_person() {
  api -o /dev/null -H 'Content-Type: application/json' -d "{\"firstName\":\"$1\",\"lastName\":\"Recovery\"}" \
    "http://localhost:$port/api/persons"
}
has_person() { api "http://localhost:$port/api/persons" | grep -q "\"firstName\" : \"$1\""; }
back_image() { kubectl -n "$namespace" get deployment microcrm-back -o jsonpath='{.spec.template.spec.containers[0].image}'; }

step "Sauvegarde puis restauration"
add_person AvantSauvegarde
BACKUP_DIR="$work" "$here/backup.sh" "$namespace"
add_person ApresSauvegarde
CONFIRM=oui "$here/restore.sh" "$(ls "$work"/*.tar.gz)" "$namespace"
has_person AvantSauvegarde || fail "la donnée sauvegardée a disparu"
if has_person ApresSauvegarde; then fail "la donnée ajoutée après la sauvegarde est encore là"; fi
echo "Données restaurées à l'état sauvegardé."

image_before=$(back_image)

step "Version qui ne démarre pas: annulation par Helm"
# Délai court: l'image n'existant pas, les pods ne seront jamais prêts. Il doit rester assez long pour que le
# retour à la version précédente, soumis au même délai, aboutisse.
# Les empreintes sont effacées (après "$@", la dernière valeur l'emporte): sinon elles désigneraient toujours les
# images installées, et la version absente ne serait jamais demandée.
if SKIP_BACKUP=1 DEPLOY_TIMEOUT=60s "$here/deploy.sh" "$env_name" 0.0.0-absente "$@" \
  --set images.digests.back= --set images.digests.front=; then
  fail "le déploiement d'une image absente aurait dû échouer"
fi
[[ "$(back_image)" = "$image_before" ]] || fail "l'image du back n'a pas été rétablie: $(back_image)"
"$here/verify_deployment.sh" "$namespace"
has_person AvantSauvegarde || fail "données perdues après l'annulation"

step "Version qui échoue au test de déploiement: retour arrière"
# Le service du front change de port: les pods sont prêts, mais l'application n'est plus joignable comme attendu.
if SKIP_BACKUP=1 SMOKE_TIMEOUT=20 "$here/deploy.sh" "$env_name" "$version" "$@" --set service.port=8099; then
  fail "le déploiement injoignable aurait dû échouer"
fi
"$here/verify_deployment.sh" "$namespace"
has_person AvantSauvegarde || fail "données perdues après le retour arrière"

echo
echo "Secours éprouvés: sauvegarde et restauration, annulation et retour arrière."
