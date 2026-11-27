#!/usr/bin/env bash
# But: job `infra-check` de la CI. Chart Helm, parité staging et production, scripts et Terraform, sans cluster : ce
# qui servira au déploiement doit se construire pour les trois environnements.
# Usage: scripts/ci/infra-check.sh     ou  scripts/ci_local.sh infra-check       (Docker, Helm et Terraform requis)
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "ÉCHEC: $*" >&2; exit 1; }
# Journaux repliables dans GitHub ; simple titre sur un poste.
title() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::group::$*"; else echo "--- $*"; fi; }
end() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::endgroup::"; fi; }
chart=deploy/helm/microcrm

title "Chart Helm, pour les trois environnements"
for environment in dev staging production; do
  values=()
  if [[ "$environment" != dev ]]; then values+=(--values "$chart/values-prodlike.yaml"); fi
  values+=(--values "$chart/values-$environment.yaml")
  helm lint "$chart" --strict "${values[@]}"
  helm template microcrm "$chart" "${values[@]}" >/dev/null
done
end

title "Staging identique à la production, hors valeurs d'installation"
scripts/check_parity.sh
end

# Le déploiement par empreinte ne sert que sur `main` : il est contrôlé ici sur chaque branche.
title "Le chart désigne les images par leur empreinte"
digest="sha256:$(printf '0%.0s' {1..64})"
rendered=$(helm template microcrm "$chart" \
  --set "images.digests.back=$digest" --set "images.digests.front=$digest")
[[ $(grep -cE "image: \"microcrm-(back|front)@$digest\"" <<<"$rendered") -eq 2 ]] ||
  fail "les deux images ne sont pas désignées par leur empreinte"
if helm template microcrm "$chart" --set images.digests.back=latest >/dev/null 2>&1; then
  fail "le chart devrait refuser une empreinte invalide"
fi
end

title "Le chart refuse plusieurs instances du back"
if helm template microcrm "$chart" --set back.replicas=2 >/dev/null 2>&1; then
  fail "le chart devrait refuser back.replicas=2"
fi
end

# Ici et non dans `lint`, réservé à ESLint et hadolint.
title "ShellCheck des scripts"
scripts/lint_scripts.sh
end

title "Terraform : mise en forme"
terraform fmt -check -recursive -diff deploy/terraform
end

title "Terraform : validation des trois environnements"
for environment in dev staging production; do
  # `-lockfile=readonly` : échec si les fournisseurs ne correspondent pas au fichier de verrouillage.
  terraform -chdir="deploy/terraform/environments/$environment" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="deploy/terraform/environments/$environment" validate
done
end

title "Terraform : tests du module platform (fournisseur simulé, sans cluster)"
terraform -chdir=deploy/terraform/modules/platform init -backend=false -input=false
terraform -chdir=deploy/terraform/modules/platform test
end
