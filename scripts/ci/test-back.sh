#!/usr/bin/env bash
# But: job `test-back` de la CI : tests du back dans l'étape de compilation du Dockerfile, avec Checkstyle et SpotBugs.
# Usage: scripts/ci/test-back.sh     ou  scripts/ci_local.sh test-back       (Docker requis)
set -euo pipefail
exec "$(dirname "$0")/../ci_test.sh" back
