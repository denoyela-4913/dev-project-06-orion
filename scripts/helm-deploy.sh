#!/usr/bin/env bash
# But: installer ou mettre à jour MicroCRM sur minikube avec Helm, en une commande.
# Fonctionnement (install et upgrade): construit les images, les charge dans minikube, puis appelle
# scripts/deploy.sh (sauvegarde, `helm upgrade --install`, test de déploiement, retour arrière en cas d'échec).
# Usage: scripts/helm-deploy.sh <install|upgrade|status|open|uninstall> <dev|staging>
#   install    première installation (refusée si la release existe déjà)
#   upgrade    nouvelle version d'une release installée
#   status     release, pods et services
#   open       port-forward vers http://localhost:8080 (Ctrl+C pour arrêter)
#   uninstall  supprime la release ; le volume de données de staging est conservé
# Raccourcis: install-dev.sh, upgrade-dev.sh, install-staging.sh, upgrade-staging.sh.
# Paramètres: SKIP_BUILD=1 (réutilise les images `microcrm-*:local` déjà construites), LOCAL_PORT (open, défaut 8080).
# L'ingress est coupé: sur le poste, l'accès passe par `open`. Pour un autre cluster, utiliser scripts/deploy.sh.
set -euo pipefail

usage() { echo "Usage: $0 <install|upgrade|status|open|uninstall> <dev|staging>" >&2; exit 2; }
[[ $# -eq 2 ]] || usage
action=$1
env_name=$2
case $action in install | upgrade | status | open | uninstall) ;; *) usage ;; esac
case $env_name in dev | staging) ;; *) usage ;; esac

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib_minikube.sh
. "$here/lib_minikube.sh"
require_minikube

release=microcrm
namespace=microcrm-$env_name
installed() { helm status "$release" -n "$namespace" >/dev/null 2>&1; }

case $action in
  status)
    helm status "$release" -n "$namespace"
    kubectl -n "$namespace" get pods,services,persistentvolumeclaims
    ;;
  open)
    port=${LOCAL_PORT:-8080}
    echo "Application sur http://localhost:$port (Ctrl+C pour arrêter)"
    exec kubectl -n "$namespace" port-forward "service/$release-front" "$port:80"
    ;;
  uninstall)
    helm uninstall "$release" -n "$namespace" --wait
    ;;
  install | upgrade)
    if [[ "$action" = install ]] && installed; then
      echo "Déjà installé dans $namespace : utiliser « upgrade » (ou « uninstall » après un échec)." >&2
      exit 1
    fi
    if [[ "$action" = upgrade ]] && ! installed; then
      echo "Rien à mettre à jour dans $namespace : utiliser « install »." >&2
      exit 1
    fi
    if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
      IMAGE_TAG=local "$here/build_images.sh"
    fi
    tag=$(local_image_tag local)
    load_into_minikube local "$tag"
    "$here/deploy.sh" "$env_name" "$tag" --set ingress.enabled=false
    echo "Pour ouvrir l'application : scripts/helm-deploy.sh open $env_name"
    ;;
esac
