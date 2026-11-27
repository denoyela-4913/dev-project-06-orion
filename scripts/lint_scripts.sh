#!/usr/bin/env bash
# But: analyser tous les scripts Bash du dépôt avec ShellCheck, de la même façon dans la CI et sur un poste.
# Fonctionnement: lance l'image officielle de ShellCheck, épinglée par digest (rien à installer, même version
# partout), sur scripts/*.sh, dépôt monté en lecture seule. Toute remarque fait échouer le script.
# Usage: scripts/lint_scripts.sh      (aucun paramètre ; Docker requis)
set -euo pipefail

# koalaman/shellcheck 0.11.0. Dependabot ne suit pas cette référence : à mettre à jour à la main.
SHELLCHECK_IMAGE="koalaman/shellcheck@sha256:bb596a0d169b85ddd81d8b6d3a2ff6d5baf5fca10b97f575ebc647c3dff62b3d"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
scripts=(scripts/*.sh)

# `-x -P scripts` : les fichiers inclus (lib_*.sh) sont analysés avec ceux qui les incluent.
docker run --rm -v "$root":/repo:ro -w /repo "$SHELLCHECK_IMAGE" -x -P scripts "${scripts[@]}"
echo "ShellCheck : ${#scripts[@]} scripts sans remarque."
