#!/usr/bin/env bash
# But: sauvegarder les données du back d'une release (volume HSQLDB) dans une archive locale.
# Fonctionnement: sauvegarde à froid, car copier les fichiers d'une base en cours d'écriture ne garantit pas leur
# cohérence. Le back est arrêté (0 instance), un pod temporaire monte le volume et son contenu est copié, puis le
# back est relancé, même si la copie échoue. Coupure de service d'une à deux minutes.
# Usage: scripts/backup.sh <espace de noms> [release]
# Paramètres: BACKUP_DIR (défaut ./backups). Sans volume (données en mémoire), le script le dit et réussit.
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: $0 <espace de noms> [release]" >&2; exit 2; }
namespace=$1
release=${2:-microcrm}
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib_volume.sh
. "$here/lib_volume.sh"

if ! has_data_volume; then
  echo "Aucun volume de données pour « $release » ($namespace): rien à sauvegarder."
  exit 0
fi

directory=${BACKUP_DIR:-backups}
mkdir -p "$directory"
# Les données comprennent des informations personnelles: archive lisible par son seul propriétaire.
umask 077
archive="$directory/${namespace}-${release}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"

with_volume_pod # définit volume_pod (lib_volume.sh)
kubectl -n "$namespace" exec "$volume_pod" -- tar -C /data -czf - . >"$archive.partial"
tar -tzf "$archive.partial" >/dev/null
mv "$archive.partial" "$archive"
echo "Sauvegarde écrite: $archive"
