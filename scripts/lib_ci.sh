# shellcheck shell=bash
# Fonctions communes à ci/compose-test.sh et ci/e2e.sh (à inclure avec `.`, pas à exécuter).
# Les essais utilisent des projets Compose « ci-<environnement> » : les conteneurs et les volumes d'une application
# lancée à la main (projets « microcrm-<environnement> ») ne sont pas touchés. Les ports doivent être libres.

export BACK_IMAGE=${BACK_IMAGE:-microcrm-back:ci}
export FRONT_IMAGE=${FRONT_IMAGE:-microcrm-front:ci}

# Journaux repliables dans GitHub ; simple titre sur un poste.
title() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::group::$*"; else echo "--- $*"; fi; }
end() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::endgroup::"; fi; }

# Environnement en cours d'essai. À la sortie : journaux si l'essai a échoué, puis suppression, volumes compris.
running=""
ci_compose() { COMPOSE_PROJECT="ci-$running" scripts/compose.sh "$running" "$@"; }
compose_cleanup() {
  local status=$?
  if [[ -n "$running" ]]; then
    if [[ $status -ne 0 ]]; then
      # Le groupe ouvert est refermé, pour que les journaux ne restent pas repliés avec l'étape en échec.
      end
      echo "--- Journaux de « $running » après l'échec"
      ci_compose logs --tail 100 || true
    fi
    ci_compose down -v >/dev/null 2>&1 || true
  fi
}
trap compose_cleanup EXIT

compose_up() {
  running=$1
  ci_compose up -d --no-build --wait --wait-timeout 180
}
compose_down() {
  ci_compose down -v
  running=""
}
