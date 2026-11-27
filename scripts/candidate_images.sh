#!/usr/bin/env bash
# But: faire passer les mêmes images du staging à la release, sans reconstruction, en les désignant par leur
# empreinte.
# Fonctionnement:
#   push: envoie les images locales sous l'étiquette « candidate » et écrit leurs empreintes, lues dans le
#         registre, au format `<cible>=sha256:…`. Le staging déploie ces empreintes.
#   tag:  après validation du staging, ajoute l'étiquette de version aux MÊMES empreintes (copie du manifeste
#         dans le registre, rien n'est reconstruit ni renvoyé), puis vérifie que l'empreinte n'a pas changé. Une
#         version déjà publiée avec une autre empreinte est refusée.
# Usage: scripts/candidate_images.sh push <préfixe/> <étiquette candidate> <fichier d'empreintes à écrire>
#        scripts/candidate_images.sh tag  <préfixe/> <version X.Y.Z> <fichier d'empreintes>
# Prérequis: `docker login` sur le registre; pour push, les images locales `microcrm-<cible>:ci`.
# Paramètres: FORCE=1 (tag) pour remplacer une version restée incomplète.
set -euo pipefail

usage() { echo "Usage: $0 <push|tag> <préfixe/> <étiquette|version> <fichier d'empreintes>" >&2; exit 2; }
fail() { echo "ÉCHEC: $*" >&2; exit 1; }
[[ $# -eq 4 ]] || usage
action=$1
# Les noms d'images n'acceptent pas les majuscules, que les noms de comptes GitHub peuvent contenir.
prefix=${2,,}
label=$3
file=$4
[[ $prefix == */ ]] || usage

targets=(front back)

# Empreinte d'une référence présente dans le registre.
digest_of() { docker buildx imagetools inspect "$1" --format '{{.Manifest.Digest}}'; }

case $action in
  push)
    [[ $label =~ ^candidate-[0-9a-f]{12}$ ]] || fail "étiquette attendue: candidate-<12 caractères du commit>"
    : >"$file"
    for target in "${targets[@]}"; do
      image="${prefix}microcrm-$target:$label"
      docker tag "microcrm-$target:ci" "$image"
      docker push --quiet "$image" >/dev/null
      digest=$(digest_of "$image")
      [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]] || fail "empreinte illisible pour $image: $digest"
      echo "$target=$digest" >>"$file"
      echo "Candidate: $image ($digest)"
    done
    ;;
  tag)
    [[ $label =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version SemVer attendue (X.Y.Z): $label"
    # Le fichier est lu ligne par ligne et vérifié, jamais exécuté.
    declare -A digests=()
    while IFS='=' read -r target digest; do
      [[ $target =~ ^(front|back)$ && $digest =~ ^sha256:[0-9a-f]{64}$ ]] ||
        fail "ligne invalide dans $file: $target=$digest"
      digests[$target]=$digest
    done <"$file"
    # Tout est contrôlé avant la première écriture.
    for target in "${targets[@]}"; do
      [[ -n "${digests[$target]:-}" ]] || fail "empreinte absente pour $target"
      image="${prefix}microcrm-$target:$label"
      if output=$(digest_of "$image" 2>&1); then
        [[ "$output" = "${digests[$target]}" || "${FORCE:-0}" = 1 ]] ||
          fail "$image est déjà publiée avec une autre empreinte ($output)"
      else
        # Seule une réponse « introuvable » autorise la publication (cf. publish_images.sh).
        grep -qiE 'not found|manifest unknown|name unknown' <<<"$output" ||
          fail "impossible de vérifier si $image existe: $output"
      fi
    done
    for target in "${targets[@]}"; do
      repository="${prefix}microcrm-$target"
      # `--prefer-index=false`: copie le manifeste tel quel, sans l'envelopper dans un index (autre empreinte).
      docker buildx imagetools create --prefer-index=false --tag "$repository:$label" \
        "$repository@${digests[$target]}" >/dev/null
      published=$(digest_of "$repository:$label")
      [[ "$published" = "${digests[$target]}" ]] ||
        fail "$repository:$label a l'empreinte $published au lieu de ${digests[$target]}"
      echo "Version: $repository:$label ($published)"
    done
    ;;
  *) usage ;;
esac
