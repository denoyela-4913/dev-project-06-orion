#!/usr/bin/env bash
# But: job `coverage` de la CI. Tests des scripts, puis seuils de couverture de 80 % pour le front et pour le back,
# sur tout le code et sur le code nouveau (scripts/coverage_gate.py, à partir des rapports des tests).
# Contrôle propre à Orion, en plus des Quality Gates Sonar : il porte aussi sur tout le code (le gate par défaut de
# Sonar ne contrôle que le code nouveau) et il tourne sur les branches de dev, où Sonar ne tourne pas.
# BLOQUANT depuis le 26/11/2026 (le front et le back ont dépassé 80 % sur tout leur code). Le réglage est écrit ici
# et non déduit des taux : un blocage automatique se désactiverait dès qu'un taux repasserait sous le seuil.
# Un rapport manquant ou un test de script en échec font aussi échouer.
# Usage: scripts/ci/coverage.sh     ou  scripts/ci_local.sh coverage, après les tests       (Python 3 et Git requis)
# Paramètres: BASE (référence Git depuis laquelle le code est « nouveau », défaut origin/main).
set -euo pipefail
cd "$(dirname "$0")/../.."

# Tests du script avant de s'y fier.
python3 -m unittest discover -s scripts
python3 scripts/coverage_gate.py --base "${BASE:-origin/main}" --blocking
