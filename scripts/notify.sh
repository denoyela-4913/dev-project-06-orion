#!/usr/bin/env bash
# But: notifier le résultat d'un déploiement.
# Fonctionnement: écrit le message dans le résumé du run GitHub (s'il existe) et sur la sortie; si NOTIFY_COMMIT=1,
# le publie en commentaire du commit (GitHub prévient par courriel les personnes abonnées); si NOTIFY_WEBHOOK_URL
# est défini, l'envoie aussi à ce webhook au format `{"text": …}` (compatible Slack, Mattermost, Teams via
# passerelle). Aucun canal externe n'est encore choisi (cf. docs/BACKLOG.md).
# Usage: scripts/notify.sh <success|failure> <message>
# Paramètres: NOTIFY_COMMIT, NOTIFY_WEBHOOK_URL, GITHUB_REPOSITORY, GITHUB_SHA, GH_TOKEN, RUN_URL.
set -euo pipefail

[[ $# -eq 2 ]] || { echo "Usage: $0 <success|failure> <message>" >&2; exit 2; }
case $1 in
  success) mark="✅ Déploiement réussi" ;;
  failure) mark="❌ Déploiement en échec" ;;
  *) echo "État inconnu: $1" >&2; exit 2 ;;
esac
text="$mark: $2"
if [[ -n "${RUN_URL:-}" ]]; then text="$text — $RUN_URL"; fi

echo "$text"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then echo "$text" >>"$GITHUB_STEP_SUMMARY"; fi
if [[ "${NOTIFY_COMMIT:-0}" = 1 ]]; then
  gh api "repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/comments" -f body="$text" >/dev/null
  echo "Commentaire ajouté au commit."
fi
if [[ -n "${NOTIFY_WEBHOOK_URL:-}" ]]; then
  # jq construit le JSON: le message ne peut pas en modifier la structure. L'adresse, secrète, n'est pas affichée.
  jq -n --arg text "$text" '{text: $text}' |
    curl --silent --show-error --fail --max-time 20 -H 'Content-Type: application/json' -d @- \
      "$NOTIFY_WEBHOOK_URL" >/dev/null 2>&1 || echo "::warning::envoi au webhook en échec" >&2
fi
