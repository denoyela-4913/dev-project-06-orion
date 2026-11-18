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

### Résoudre les CVE (en particulier les critiques) en mettant à jour les briques obsolètes

Constat sur l'état initial (tag `v0.0.1`, analyse du 18/11/2026, dates de fin de support d'après endoflife.date):
`npm install` du front signale 90 vulnérabilités (7 low, 27 moderate, 51 high, 5 critical),
cf. `docs/logbook/0.0.1-initial-state/front.log`. Les 8 vulnérabilités des dépendances de production
viennent d'Angular et ne se corrigent qu'avec Angular 22. Les 5 critiques sont transitives
(`piscina`, `tar`, `proxy-addr`, `shell-quote`, `websocket-driver`): `piscina` et `tar` disparaissent avec
`@angular-devkit/build-angular` et `@angular/cli` récents, les trois autres se corrigent sans montée majeure.

Critère de choix des versions: version LTS quand elle existe, et fin de support postérieure à 05/2027.

| Brique | Actuelle (fin de support) | Cible (fin de support) |
|---|---|---|
| Angular | 17.3 (15/05/2025, dépassée) | 22 (30/06/2028) |
| Spring Boot | 3.2.5 (31/12/2024, dépassée) | 4.1.x (31/07/2027) |
| Alpine | 3.19 (01/11/2025, dépassée) | 3.24 (01/06/2028) |
| Node.js | 20 (30/04/2026, dépassée) | 24 LTS (30/04/2028) |
| Java | 17 pour compiler, 21 dans l'image | 21 LTS (31/12/2029) partout |
| Gradle | 8.7 | 9.x, dernière mineure (pas de LTS ni de date de support, cf. ci-dessous) |

Gradle n'a pas de LTS (vérifié sur la politique officielle, docs.gradle.org, feature_lifecycle, et sur
endoflife.date). Seule la dernière mineure de la dernière majeure est pleinement supportée (9.9.1 au
18/11/2026). La majeure précédente (8.14.x) ne reçoit plus que les correctifs critiques et de sécurité,
jusqu'à la sortie de la majeure suivante, sans date publiée. Le critère « fin de support après 05/2027 »
ne peut donc pas être garanti pour Gradle: on vise la dernière mineure de la 9.x et on met à jour le
wrapper (`./gradlew wrapper --gradle-version <x>`) à chaque nouvelle mineure.

Les cibles Spring Boot 4.1 et Angular 22 dépassent 05/2027 de peu pour Spring Boot (07/2027): réévaluer
la cible au moment de la migration si une version plus récente est sortie.

- [ ] front: migrer Angular 17 → 22
  - Une majeure à la fois avec `ng update` (18, 19, 20, 21, 22), tests et build verts à chaque étape.
  - TypeScript, zone.js, rxjs et outils de test (karma, jasmine) suivent les versions exigées par Angular.
  - Vérifier la compatibilité d'Angular 22 avec Node 24 (matrice de compatibilité officielle).
  - Résultat attendu: `npm audit` sans critique et sans vulnérabilité sur les dépendances de production.
- [ ] back: migrer Spring Boot 3.2.5 → 4.1.x
  - Passer par les étapes documentées (3.5, puis 4.0, puis 4.1), tests verts à chaque étape.
  - Mettre à jour Gradle (dernière mineure de la 9.x, ou au minimum la version exigée par Spring Boot,
    à confirmer dans ses notes de version) et les plugins.
  - Vérifier l'état de maintenance de `ro.polak:spring-boot-data-fixtures:0.2.0`, remplacer si abandonnée.
  - Passer `sourceCompatibility` à Java 21.
- [ ] docker: mettre à jour les images
  - Alpine 3.19 → 3.24 (vérifier la disponibilité de `caddy`, `openjdk21-jre-headless`, `supervisor`).
  - Aligner Java sur 21 entre compilation (`gradle:jdk17` → image JDK 21) et exécution.
  - Remplacer `node` et `gradle:*` en `latest` par des versions fixes (cf. tâche des versions figées).
- [ ] ci: aligner le workflow sur les nouvelles versions
  - `node-version: 20` → 24, `java-version: 17` → 21, dans `.github/workflows/ci.yml`.
  - À faire en même temps que les migrations front et back correspondantes, pas avant.
- [ ] sécurité: auditer le back et les images, puis scanner dans la CI
  - Back (Gradle) et images Docker n'ont pas encore été analysés.
  - Ajouter un scan de vulnérabilités dans la CI une fois les mises à jour faites, pour ne pas les réintroduire.

## Fait

- [x] ci: workflow GitHub Actions équivalent à `.gitlab-ci.yml`
