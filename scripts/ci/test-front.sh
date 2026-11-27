#!/usr/bin/env bash
# But: job `test-front` de la CI : tests du front dans l'étape de compilation du Dockerfile.
# Usage: scripts/ci/test-front.sh     ou  scripts/ci_local.sh test-front       (Docker requis)
set -euo pipefail
exec "$(dirname "$0")/../ci_test.sh" front
