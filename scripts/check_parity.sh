#!/usr/bin/env bash
# But: garantir que le staging est identique à la production, hors valeurs propres à une installation.
# Fonctionnement, sans cluster:
#   - Helm: les manifestes des deux environnements, rendus avec les MÊMES valeurs d'installation (origine
#     publique, domaine, Secret TLS), doivent être identiques. Tout autre réglage écrit pour un seul des deux
#     fait donc échouer le contrôle;
#   - Terraform: les deux dossiers ne diffèrent que par le nom de l'environnement (commentaires ignorés);
#   - Compose: la configuration résolue avec le même fichier de valeurs doit être identique.
# Usage: scripts/check_parity.sh
# Prérequis: helm et docker compose.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
chart="$root/deploy/helm/microcrm"
status=0

differ() { echo "ÉCHEC: $1 diffère entre staging et production" >&2; status=1; }

render() {
  local environment=$1
  local values=()
  if [[ -f "$chart/values-prodlike.yaml" ]]; then values+=(--values "$chart/values-prodlike.yaml"); fi
  helm template microcrm "$chart" "${values[@]}" --values "$chart/values-$environment.yaml" \
    --set publicUrl=https://parite.invalid --set ingress.host=parite.invalid --set ingress.tlsSecretName=parite-tls
}
diff <(render staging) <(render production) >&2 || differ "le rendu Helm"

for file in main.tf variables.tf providers.tf versions.tf outputs.tf; do
  diff <(sed -e '/^[[:space:]]*#/d' -e 's/staging/ENV/g' "$root/deploy/terraform/environments/staging/$file") \
    <(sed -e '/^[[:space:]]*#/d' -e 's/production/ENV/g' "$root/deploy/terraform/environments/production/$file") >&2 ||
    differ "Terraform ($file)"
done

# Même projet et mêmes valeurs pour les deux: seuls les fichiers Compose choisis par compose.sh peuvent différer.
resolve() {
  COMPOSE_ENV_FILE="$root/deploy/compose/env/production.env" COMPOSE_PROJECT=parite \
    "$root/scripts/compose.sh" "$1" config
}
diff <(resolve staging) <(resolve production) >&2 || differ "la configuration Compose"

[[ "$status" -ne 0 ]] || echo "Staging et production sont identiques, hors valeurs d'installation."
exit "$status"
