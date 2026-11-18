# Backlog

## À faire

- [ ] ci: ajouter le cache npm et Gradle (`cache:` de `setup-node` / `setup-java`)
  - Pré-requis: mesurer les durées de run sans cache (`gh run view`), puis avec cache.
  - Justification: gain non démontré, retiré du premier workflow.

- [ ] ci: figer les versions des COTS (composants tiers), jamais `latest`, et les référencer par SHA
  - Actions GitHub: remplacer `@v4` par le SHA du commit (`uses: actions/checkout@<sha> # v4.x.y`),
    car un tag est déplaçable alors qu'un SHA est immuable (sécurité supply chain, reproductibilité).
  - À traiter aussi: `ubuntu-latest` (runner) et les images Docker `node:latest` (`Dockerfile`),
    à remplacer par une version fixe (pour les images, par digest `@sha256:...`).
  - Inclure la mise à jour des actions signalée par les avertissements du premier run
    (`checkout`, `setup-node`, `setup-java` v4 dépréciés / Node 20).
  - Suivi des mises à jour: Dependabot (`github-actions` et `docker`) pour proposer les nouveaux SHA.

## Fait

- [x] ci: workflow GitHub Actions équivalent à `.gitlab-ci.yml`
