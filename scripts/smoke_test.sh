#!/usr/bin/env bash
# But: test de déploiement (santé HTTP) d'une instance déployée, à travers le front.
# Fonctionnement: vérifie la santé du front et du back, les réglages du front, la lecture de l'API et un cycle
# création/suppression d'une personne. Sort en erreur au premier contrôle en échec.
# Usage: scripts/smoke_test.sh <URL du front>     ex.: scripts/smoke_test.sh http://localhost:4280
# Paramètres: SMOKE_TIMEOUT (attente maximale du démarrage, en secondes, défaut 120) ; SMOKE_INSECURE=1 accepte
# un certificat non reconnu (autorité interne de Caddy).
set -euo pipefail

base=${1:?Usage: $0 <URL du front>}
base=${base%/}
timeout=${SMOKE_TIMEOUT:-120}
curl_options=(--silent --show-error --fail --max-time 10)
if [[ "${SMOKE_INSECURE:-0}" = 1 ]]; then curl_options+=(--insecure); fi

fetch() { curl "${curl_options[@]}" "$@"; }
fail() { echo "ÉCHEC: $*" >&2; exit 1; }
pass() { echo "OK: $*"; }

deadline=$((SECONDS + timeout))
until fetch "$base/api/actuator/health/readiness" >/dev/null 2>&1; do
  [[ "$SECONDS" -lt "$deadline" ]] || fail "l'application ne répond pas après ${timeout}s ($base)"
  sleep 3
done
pass "le back est prêt"

fetch "$base/healthz" >/dev/null || fail "santé du front"
pass "le front est en bonne santé"

page=$(fetch "$base/") || fail "page d'accueil"
grep -q '<app-root' <<<"$page" || fail "la page d'accueil ne contient pas l'application"
route=$(fetch "$base/persons/1") || fail "route de l'application"
grep -q '<app-root' <<<"$route" || fail "une route de l'application ne renvoie pas la page (repli SPA)"
pass "le front sert l'application, routes comprises"

config=$(fetch "$base/config.js") || fail "réglages du front"
grep -q '"apiBaseUrl": "/api"' <<<"$config" || fail "le front n'appelle pas l'API par /api: $config"
pass "le front est réglé sur /api"

organizations=$(fetch "$base/api/organizations") || fail "lecture des organisations"
grep -q '_embedded' <<<"$organizations" || fail "réponse inattendue de l'API"
pass "l'API répond à travers le front"

# Écriture avec l'en-tête Origin d'un navigateur: détecte un réglage CORS qui bloquerait le front.
created=$(fetch -H "Origin: $base" -H 'Content-Type: application/json' \
  -d '{"firstName":"Smoke","lastName":"Test","email":"smoke@example.net"}' "$base/api/persons") ||
  fail "création d'une personne (vérifier APP_CORS_ALLOWED_ORIGINS)"
id=$(sed -n 's/.*"id" *: *\([0-9][0-9]*\).*/\1/p' <<<"$created" | head -n 1)
[[ -n "$id" ]] || fail "identifiant absent de la réponse de création"
fetch -X DELETE -H "Origin: $base" "$base/api/persons/$id" >/dev/null || fail "suppression de la personne $id"
pass "création puis suppression d'une personne"

echo "Test de déploiement réussi: $base"
