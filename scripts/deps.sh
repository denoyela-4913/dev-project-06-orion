#!/usr/bin/env bash
# But: gérer les dépendances du front et du back sans avoir à retenir les options de chaque outil.
# Usage: scripts/deps.sh <install|lock|outdated> [front|back|all]       (cible par défaut: all)
#   install   installe exactement les versions verrouillées ; échoue si le verrou ne correspond plus au projet
#             (front: `npm ci` ; back: résolution et compilation avec le verrou Gradle STRICT)
#   lock      réécrit les verrous après un changement de package.json ou de build.gradle (à relire et commiter)
#   outdated  liste les paquets du front en retard (information seulement ; Gradle n'a pas d'équivalent intégré)
# `--ignore-scripts` partout côté npm : les scripts d'installation des paquets ne sont pas exécutés (chaîne
# d'approvisionnement). La CI installe le front avec ce script.
set -euo pipefail

usage() { echo "Usage: $0 <install|lock|outdated> [front|back|all]" >&2; exit 2; }
[[ $# -ge 1 && $# -le 2 ]] || usage
action=$1
target=${2:-all}
case $action in install | lock | outdated) ;; *) usage ;; esac
case $target in front | back | all) ;; *) usage ;; esac
root="$(cd "$(dirname "$0")/.." && pwd)"

front() {
  cd "$root/front"
  case $action in
    install) npm ci --ignore-scripts ;;
    lock) npm install --package-lock-only --ignore-scripts ;;
    # `npm outdated` sort en 1 dès qu'un paquet est en retard : ce n'est pas une erreur ici.
    outdated) npm outdated || [[ $? -eq 1 ]] ;;
  esac
}

back() {
  cd "$root/back"
  case $action in
    # Pas la tâche `dependencies` : elle signale une dépendance non résolue sans sortir en erreur.
    install) ./gradlew testClasses ;;
    lock) ./gradlew dependencies --write-locks ;;
    outdated) echo "Back : pas de liste intégrée à Gradle (versions déclarées dans back/build.gradle)." ;;
  esac
}

# Appels directs, hors `&&` : sinon `set -e` serait ignoré dans les fonctions.
if [[ "$target" != back ]]; then front; fi
if [[ "$target" != front ]]; then back; fi
