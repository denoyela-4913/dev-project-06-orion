#!/usr/bin/env bash
# But: tester une partie de l'application dans l'étape de compilation du Dockerfile, et en sortir le produit que les
# images réutiliseront. Utilisé par les jobs `test-front` et `test-back`, et lançable sur un poste.
# Fonctionnement: construit l'étape `<partie>-build`, extrait son produit dans artifacts/<partie> (front compilé ou
# JAR), joue les tests (et pour le back Checkstyle et SpotBugs) dans un conteneur de cette étape, puis copie les
# rapports là où les attendent scripts/coverage_gate.py et SonarQube. Un échec fait échouer le script, après la copie
# des rapports.
# Usage: scripts/ci_test.sh <front|back>      (Docker requis)
set -euo pipefail

usage() { echo "Usage: $0 <front|back>" >&2; exit 2; }
[[ $# -eq 1 ]] || usage
part=$1
case $part in
  front) tests=(npm test -- --watch=false --coverage) ;;
  # `check` : tests, Checkstyle et SpotBugs (bloquants avec zéro écart, cf. back/build.gradle). `--continue` : un
  # premier échec n'empêche pas les autres contrôles de produire leur rapport.
  back) tests=(./gradlew check --continue) ;;
  *) usage ;;
esac

cd "$(dirname "$0")/.."
image="microcrm-$part-build:ci"

docker build --target "$part-build" --tag "$image" .
# Même étape, donc tirée du cache : le produit extrait est celui de l'image testée. Le dossier est vidé d'abord,
# pour ne pas mélanger deux compilations.
rm -rf "artifacts/$part"
docker build --target "$part-dist" --output "type=local,dest=artifacts/$part" .

# Conteneur gardé après les tests pour en copier les rapports (aucun dossier du dépôt n'y est monté : rien n'y est
# écrit avec les droits de root).
container=$(docker create --env CI=true "$image" "${tests[@]}")
trap 'docker rm --force "$container" >/dev/null' EXIT
# Un échec est gardé pour la fin : les rapports d'un contrôle en échec sont ceux qu'on veut lire (et que SonarQube
# importe).
status=0
docker start --attach "$container" || status=$?

# copy <chemin dans le conteneur> <destination> : obligatoire si tout a réussi. Après un échec, un rapport peut ne
# pas exister (compilation arrêtée, par exemple) : les autres sont tout de même copiés.
copy() {
  rm -rf "$2"
  mkdir -p "$(dirname "$2")"
  docker cp "$container:$1" "$2" || [[ $status -ne 0 ]]
}

case $part in
  front)
    copy /src/coverage/microcrm/lcov.info front/coverage/microcrm/lcov.info
    ;;
  back)
    copy /src/build/classes/java back/build/classes/java
    copy /src/build/reports/jacoco/test/jacocoTestReport.xml back/build/reports/jacoco/test/jacocoTestReport.xml
    copy /src/build/reports/checkstyle back/build/reports/checkstyle
    copy /src/build/reports/spotbugs back/build/reports/spotbugs
    # Les rapports XML désignent les sources par leur chemin dans le conteneur (/src/src/…), que SonarQube ne
    # retrouverait pas : il est rendu relatif au dossier back/.
    for report in back/build/reports/checkstyle/*.xml back/build/reports/spotbugs/*.xml; do
      if [[ -f $report ]]; then sed -i 's#/src/src/#src/#g' "$report"; fi
    done
    ;;
esac

if [[ $status -ne 0 ]]; then
  echo "ÉCHEC ($part) : voir les messages ci-dessus et les rapports copiés" >&2
  exit "$status"
fi
echo "Tests réussis ($part). Produit : artifacts/$part"
