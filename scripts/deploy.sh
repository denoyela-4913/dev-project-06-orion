#!/usr/bin/env bash
# But: déployer une version avec Helm, vérifier qu'elle répond, et revenir en arrière sinon. C'est aussi la
# livraison manuelle de secours: elle ne dépend que de kubectl et helm, pas de la CI.
# Fonctionnement: 1) sauvegarde des données si une version est déjà installée avec des données conservées;
# 2) `helm upgrade --install` qui annule de lui-même si les pods ne deviennent pas prêts; 3) test de déploiement
# (scripts/smoke_test.sh) à travers un port-forward; 4) en cas d'échec du test, `helm rollback`.
# Usage: scripts/deploy.sh <dev|staging|production> <version> [options helm...]
# Exemple: scripts/deploy.sh staging 0.1.0 --set images.repositoryPrefix=ghcr.io/<propriétaire>/<dépôt>/
# Pour désigner les images par leur empreinte (celles de images-digests.env d'une release), ajouter
# --set images.digests.back=sha256:… --set images.digests.front=sha256:…
# Paramètres: NAMESPACE (défaut microcrm-<env>), RELEASE (défaut microcrm), DEPLOY_TIMEOUT (défaut 5m),
# BACKUP_DIR (défaut ./backups), SKIP_BACKUP=1, LOCAL_PORT (port du port-forward, défaut 18080).
# Le cluster visé est le contexte courant de kubectl (KUBECONFIG).
set -euo pipefail

usage() { echo "Usage: $0 <dev|staging|production> <version> [options helm...]" >&2; exit 2; }
[[ $# -ge 2 ]] || usage
env_name=$1
version=$2
shift 2
case $env_name in dev | staging | production) ;; *) usage ;; esac
[[ $version =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]] || { echo "Version invalide: $version" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
chart="$here/../deploy/helm/microcrm"
release=${RELEASE:-microcrm}
namespace=${NAMESPACE:-microcrm-$env_name}
timeout=${DEPLOY_TIMEOUT:-5m}

previous=$(helm list -n "$namespace" --filter "^${release}\$" --deployed -o json 2>/dev/null |
  python3 -c 'import json,sys; r=json.load(sys.stdin); print(r[0]["revision"] if r else "")' || true)

if [[ -n "$previous" ]] && [[ "${SKIP_BACKUP:-0}" != 1 ]]; then
  "$here/backup.sh" "$namespace" "$release"
fi

# Helm 4 a renommé `--atomic` en `--rollback-on-failure`.
atomic=--atomic
# Aide lue d'abord en entier: avec `pipefail`, un `grep -q` qui s'arrête tôt pourrait faire échouer le tube.
upgrade_help=$(helm upgrade --help)
if grep -q -- '--rollback-on-failure' <<<"$upgrade_help"; then atomic=--rollback-on-failure; fi

# Staging et production partagent values-prodlike.yaml, puis chacun ajoute ses valeurs d'installation.
values=()
if [[ "$env_name" != dev ]]; then values+=(--values "$chart/values-prodlike.yaml"); fi
values+=(--values "$chart/values-$env_name.yaml")

echo "Déploiement de $version sur « $env_name » (espace de noms $namespace)"
helm upgrade --install "$release" "$chart" \
  --namespace "$namespace" --create-namespace \
  "${values[@]}" \
  --set-string "images.tag=$version" \
  --wait --timeout "$timeout" "$atomic" \
  "$@"

if ! "$here/verify_deployment.sh" "$namespace" "$release"; then
  echo "Le test de déploiement a échoué." >&2
  if [[ -n "$previous" ]]; then
    "$here/rollback.sh" "$namespace" "$release" "$previous"
  else
    echo "Première installation: aucune version à restaurer, la release est laissée pour le diagnostic." >&2
  fi
  exit 1
fi
echo "Version $version déployée et vérifiée."
