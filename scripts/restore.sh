#!/usr/bin/env bash
# But: restaurer les données du back d'une release à partir d'une archive de scripts/backup.sh.
# Fonctionnement: arrête le back, REMPLACE le contenu du volume par celui de l'archive, relance le back.
# Usage: scripts/restore.sh <archive.tar.gz> <espace de noms> [release]
# Paramètres: CONFIRM=oui est exigé, car les données actuelles du volume sont effacées.
set -euo pipefail

[ $# -ge 2 ] || { echo "Usage: CONFIRM=oui $0 <archive> <espace de noms> [release]" >&2; exit 2; }
archive=$1
namespace=$2
release=${3:-microcrm}
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib_volume.sh
. "$here/lib_volume.sh"

tar -tzf "$archive" >/dev/null || { echo "Archive illisible: $archive" >&2; exit 1; }
[ "${CONFIRM:-}" = oui ] || { echo "Les données actuelles seront effacées: relancer avec CONFIRM=oui." >&2; exit 1; }
has_data_volume || { echo "Aucun volume de données pour « $release » ($namespace)." >&2; exit 1; }

with_volume_pod # définit volume_pod (lib_volume.sh)
kubectl -n "$namespace" exec "$volume_pod" -- sh -c 'find /data -mindepth 1 -delete'
kubectl -n "$namespace" exec -i "$volume_pod" -- tar -C /data -xzf - <"$archive"
echo "Données restaurées depuis $archive"
