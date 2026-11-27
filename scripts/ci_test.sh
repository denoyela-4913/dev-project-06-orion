#!/usr/bin/env bash
# But: tester une partie de l'application dans l'étape de compilation du Dockerfile, et en sortir le produit que les
# images réutiliseront. Utilisé par les jobs `test-front` et `test-back`, et lançable sur un poste.
# Fonctionnement: construit l'étape `<partie>-build`, extrait son produit dans artifacts/<partie> (front compilé ou
# JAR), joue les tests dans un conteneur de cette étape, puis copie les rapports là où les attendent
# scripts/coverage_gate.py et SonarQube. Un test en échec fait échouer le script.
# Usage: scripts/ci_test.sh <front|back>      (Docker requis)
set -euo pipefail

usage() { echo "Usage: $0 <front|back>" >&2; exit 2; }
[[ $# -eq 1 ]] || usage
part=$1
case $part in
  front) tests=(npm test -- --watch=false --coverage) ;;
  back) tests=(./gradlew test) ;;
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
docker start --attach "$container"

case $part in
  front)
    mkdir -p front/coverage/microcrm
    docker cp "$container:/src/coverage/microcrm/lcov.info" front/coverage/microcrm/lcov.info
    ;;
  back)
    # `docker cp` d'un dossier vers un dossier existant l'y imbriquerait.
    rm -rf back/build/classes/java
    mkdir -p back/build/classes back/build/reports/jacoco/test
    docker cp "$container:/src/build/classes/java" back/build/classes/java
    docker cp "$container:/src/build/reports/jacoco/test/jacocoTestReport.xml" \
      back/build/reports/jacoco/test/jacocoTestReport.xml
    ;;
esac
echo "Tests réussis ($part). Produit : artifacts/$part"
