#!/usr/bin/env bash
# Exporte d'un coup les trois projets SonarQube Cloud (front, back, infra) pour une version, sous
# <dossier>/<version>/<partie>/. Appelle scripts/sonar-export.sh pour chaque partie.
#
# Pourquoi un contrôle de révision: SonarQube Cloud ne garde que l'état COURANT d'une branche, pas celui d'un
# tag git. Un cliché « v0.1.0 » n'a de valeur que si la dernière analyse de `main` porte sur le commit du tag.
# Le script compare donc la révision de la dernière analyse de chaque projet avec le commit du tag, AVANT
# d'exporter quoi que ce soit, pour ne pas écrire un cliché trompeur ou à moitié fait.
#
# Mode strict de bash: arrêt immédiat sur une erreur, variable non définie interdite, échec d'un pipeline
# détecté (cf. scripts/sonar-export.sh).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sonar-export-release.sh [-o dossier] [-f] <version>

  <version>  tag git existant, par exemple v0.1.0 (le tag doit être créé avant l'export)
  -o         dossier de base des clichés, créé si besoin   (défaut: docs/quality)
  -f         forcer: exporter même si la dernière analyse de `main` ne porte pas sur le commit du tag
  -h         cette aide

Produit <dossier>/<version>/<partie>/sonar-<partie>-main-{measures,issues}.json pour chaque partie.
Attendre que la CI de `main` ait terminé l'analyse du commit tagué avant de lancer le script.
EOF
}

out=docs/quality
force=false
while getopts "o:fh" opt; do
  case $opt in
    o) out=$OPTARG ;;
    f) force=true ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi
version=$1
# Une version commençant par « - » serait lue comme une option par git ou par les scripts appelés.
if [[ "$version" == -* ]]; then
  echo "Version invalide: '$version'" >&2
  exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
parts=(front back infra)

tag_commit=$(git -C "$here" rev-parse --verify --quiet "refs/tags/$version^{commit}") || {
  echo "Tag git '$version' introuvable. Créez-le d'abord (git tag), puis relancez." >&2
  exit 1
}

# Clé du projet: même règle que scripts/sonar-export.sh (remote git, rien d'écrit en dur).
slug=$(git -C "$here" remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
base_key=${slug/\//_}

# Révision de la dernière analyse de `main` d'un projet (champ "revision" de l'API).
analysis_revision() {
  curl -fsS -G "https://sonarcloud.io/api/project_analyses/search" \
    --data-urlencode "project=$1" --data-urlencode "branch=main" --data-urlencode "ps=1" \
    | grep -o '"revision":"[^"]*"' | head -1 | cut -d'"' -f4 || true
}

mismatch=false
for part in "${parts[@]}"; do
  revision=$(analysis_revision "${base_key}_${part}")
  if [[ "$revision" != "$tag_commit" ]]; then
    echo "Projet '$part': dernière analyse de main sur '${revision:-aucune}', le tag $version est sur $tag_commit." >&2
    mismatch=true
  fi
done
if [[ "$mismatch" == true && "$force" != true ]]; then
  echo "Aucun export écrit. Attendez la fin de la CI de main sur le commit du tag, ou forcez avec -f." >&2
  exit 1
fi

for part in "${parts[@]}"; do
  "$here/sonar-export.sh" -p "$part" -b main -o "$out/$version/$part"
done
echo "Cliché $version écrit dans $out/$version/ (front, back, infra)."
