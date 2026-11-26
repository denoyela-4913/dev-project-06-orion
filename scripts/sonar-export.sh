#!/usr/bin/env bash
# Exporte les mesures et les issues SonarQube Cloud d'une branche, au format JSON.
# Utilise l'API publique (projet public): aucun jeton nécessaire.
#
# Attention: la requête porte sur l'état COURANT de la branche demandée (pas sur un tag git).
# Pour garder un état à une date donnée, versionner les JSON produits.
# Mode strict de bash, pour qu'une erreur arrête le script au lieu de produire un export incomplet:
#   -e          arrêt immédiat si une commande échoue (code de sortie non nul)
#   -u          erreur si on utilise une variable non définie (évite les fautes de frappe silencieuses)
#   -o pipefail dans un pipeline (a | b), l'échec de n'importe quelle commande compte, pas seulement
#               celui de la dernière (ex.: `git remote get-url origin | sed ...`)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sonar-export.sh [-b branche] [-o dossier] [-p partie] [-k clé_projet]

  -b  branche à exporter                        (défaut: main)
  -o  dossier de sortie, créé si besoin         (défaut: dossier courant)
  -p  partie du dépôt: front, back ou infra (projet <propriétaire>_<dépôt>_<partie>); sans -p, le projet
                                                 historique <propriétaire>_<dépôt>, qui n'est plus analysé
                                                 depuis le 26/11/2026
  -k  clé du projet SonarQube Cloud             (défaut: variable SONAR_PROJECT_KEY, sinon
                                                 déduite du remote git `origin`: <propriétaire>_<dépôt>)

Fichiers produits: sonar-<branche>-measures.json et sonar-<branche>-issues.json, précédés de la partie avec -p
(les "/" du nom de branche sont remplacés par "-").
EOF
}

branch=main
out=.
part=
key=${SONAR_PROJECT_KEY:-}

while getopts "b:o:p:k:h" opt; do
  case $opt in
    b) branch=$OPTARG ;;
    o) out=$OPTARG ;;
    p) part=$OPTARG ;;
    k) key=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

# Clé déduite du remote git (convention d'un projet importé depuis GitHub), pour ne pas l'écrire en dur.
if [[ -z "$key" ]]; then
  slug=$(git -C "$(dirname "$0")" remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
  key=${slug/\//_}
  # Un projet par partie depuis le 26/11/2026 (modèle de la documentation Sonar pour les monorepos).
  if [[ -n "$part" ]]; then key=${key}_${part}; fi
fi

api=https://sonarcloud.io/api
page_size=500
metrics=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc,reliability_rating,security_rating,sqale_rating
name=${branch//\//-}
if [[ -n "$part" ]]; then name="$part-$name"; fi

mkdir -p "$out"

# Télécharge vers un fichier temporaire pour ne jamais laisser un fichier partiel ou une erreur d'API
# à la place d'un export valide.
fetch() {
  local target=$1 endpoint=$2
  shift 2
  if curl -fsS -G "$api/$endpoint" --data-urlencode "branch=$branch" "$@" -o "$target.tmp"; then
    mv "$target.tmp" "$target"
  else
    rm -f "$target.tmp"
    echo "Échec de la récupération de $endpoint (projet '$key', branche '$branch')" >&2
    return 1
  fi
}

fetch "$out/sonar-$name-measures.json" measures/component \
  --data-urlencode "component=$key" --data-urlencode "metricKeys=$metrics"
fetch "$out/sonar-$name-issues.json" issues/search \
  --data-urlencode "componentKeys=$key" --data-urlencode "resolved=false" --data-urlencode "ps=$page_size"

total=$(grep -o '"total":[0-9]*' "$out/sonar-$name-issues.json" | head -1 | cut -d: -f2)
if [[ "${total:-0}" -gt "$page_size" ]]; then
  echo "Attention: $total issues, seules les $page_size premières sont exportées (pas de pagination)." >&2
fi

echo "Export écrit dans $out: sonar-$name-measures.json, sonar-$name-issues.json (${total:-?} issues)"
