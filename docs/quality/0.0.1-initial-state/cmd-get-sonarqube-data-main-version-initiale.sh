#!/usr/bin/env bash
# Récupère les mesures et les issues SonarQube Cloud de la branche `main`.
# Attention: la requête porte sur la branche `main` (état COURANT), pas sur le tag v0.0.1.
# Les JSON versionnés à côté de ce script sont le cliché pris le 18/11/2026 (commit 5f06502).
# Relancer ce script après la fusion de la PR donnerait un état différent.
set -euo pipefail

# Écrit les JSON à côté du script, quel que soit le répertoire d'appel.
cd "$(dirname "$0")"

K=denoyela-4913_dev-project-06-orion
curl -s "https://sonarcloud.io/api/measures/component?component=$K&branch=main&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc,reliability_rating,security_rating,sqale_rating" > sonar-main-measures.json
curl -s "https://sonarcloud.io/api/issues/search?componentKeys=$K&branch=main&resolved=false&ps=500" > sonar-main-issues.json
