# Cliché intermédiaire v0.0.2: composants mis à jour

Cliché de la branche `main` analysée par le job `sonar` de la CI (`sonarqube-scan-action`, avec couverture) au commit
`078d971`, le 18/11/2026 à 22:48 UTC. Le tag git `v0.0.2` pointe sur ce commit. Il fait suite à
[`../0.0.1-initial-state/`](../0.0.1-initial-state/) et [`../sonar-ci-scan-baseline/`](../sonar-ci-scan-baseline/)
(même code que `v0.0.1`, analysé par la CI: **base de comparaison à utiliser**).

Ce que contient ce cliché par rapport à la base: Spring Boot 4.1.2, Gradle 9.9.1, Java 21, Angular 22 (TypeScript 6),
Alpine 3.24, Bulma servi par npm, dépendances Gradle verrouillées, images Docker épinglées par digest et exécutées
sans root, Dependabot et CI épinglée par SHA. **Aucune correction du code applicatif du front** (bugs et code smells
Sonar, bugs fonctionnels): elles font l'objet de la suite, jusqu'au jalon `v0.1.0`.

Commandes utilisées (depuis la racine du dépôt):

```bash
scripts/sonar-export.sh -b main -o docs/quality/0.0.2-components-upgraded
curl -s "https://sonarcloud.io/api/qualitygates/project_status?projectKey=<clé du projet>&branch=main" \
  > docs/quality/0.0.2-components-upgraded/sonar-main-quality-gate.json
curl -s "https://sonarcloud.io/api/measures/component_tree?component=<clé du projet>&branch=main&metricKeys=coverage,line_coverage,lines_to_cover,uncovered_lines,conditions_to_cover,uncovered_conditions&qualifiers=FIL&ps=200&strategy=leaves" \
  > docs/quality/0.0.2-components-upgraded/sonar-main-coverage-by-file.json
```

Relancer ces commandes donne l'état courant de `main`, pas celui de ce cliché.

## SonarQube: comparaison

| Mesure | État initial (analyse auto, `v0.0.1`) | Base CI (même code) | **v0.0.2** |
|---|---|---|---|
| Issues | 35 | 39 | **33** |
| Vulnérabilités | 6 | 6 | **0** |
| Bugs | 20 | 24 | 24 |
| Code smells | 9 | 9 | 9 |
| Note de sécurité | C | C | **A** |
| Note de fiabilité | C | C | C |
| Note de maintenabilité | A | A | A |
| Couverture | non mesurée | 37,1 % | 37,1 % |
| Duplication | 0,0 % | 1,7 % | 1,6 % |
| Lignes de code (ncloc) | 1 010 | 1 286 | 1 386 |
| Quality Gate de `main` | non calculé | OK | **ERROR** |

Lecture:

- **Les 6 vulnérabilités sont corrigées**: `S6505` (×2) et `S8543` (Dockerfile), `S5725` (Bulma sans intégrité),
  `S8569` (verrou Gradle) et `S6471` (image en root).
- **Les 24 bugs et les 9 code smells sont inchangés**: ce sont les issues du front, non traitées à ce stade
  (promesses non gérées `typescript:S9383` ×16, champs de formulaire sans label `Web:InputWithoutLabelCheck` ×7,
  labels `Web:S6853` ×6, `Number.parseInt` ×2, `<th>` manquants ×1, opération asynchrone dans un constructeur ×1).
  Les migrations Angular (17 → 22) n'ont ni ajouté ni supprimé d'issue.
- **Le Quality Gate de `main` est en échec**, pour une seule condition: `new_coverage` = 0,0 % (seuil 80 %). Les autres
  conditions (fiabilité, sécurité, maintenabilité, duplication, hotspots relus) sont vertes. Hypothèse non vérifiée:
  Sonar compte comme code nouveau les lignes modifiées par les migrations Angular, que les tests ne couvrent pas.
  Sur la base CI, le gate était OK avec la même couverture: la condition n'avait pas encore de code « nouveau » à juger
  (hypothèse, non vérifiée).
- **Lignes de code +100**: écart non analysé en détail. Probables contributeurs: `bulma.scss`, la configuration et les
  migrations Angular (`@if`/`@for`, `changeDetection`).

### Couverture

Inchangée par rapport à la base CI (aucun test ajouté):

| Zone | Lignes à couvrir | Non couvertes | Couverture (lignes) |
|---|---|---|---|
| Back | 70 | 28 | 60,0 % |
| Front | 122 | 86 | 29,5 % |
| Total | 192 | 114 | 40,6 % |

Le 37,1 % de Sonar inclut aussi les conditions. Détail par fichier: `sonar-main-coverage-by-file.json`.

## Dépendances

| | `v0.0.1` | `v0.0.2` |
|---|---|---|
| `npm audit` (front) | 90 vulnérabilités (7 low, 27 moderate, 51 high, 5 critiques) | **0** |

Le back n'a pas encore été audité (tâche « sécurité » du backlog).

## Durées de la CI

Mesure sur les 14 runs réussis du workflow `CI` avec la configuration actuelle (Node 24, Java 21, sans cache),
entre le 18/11/2026 22:02 et 22:48 UTC (runs `push` et `pull_request`, les runs Dependabot exclus):

```bash
gh run list --limit 60 --json databaseId,event,conclusion,headBranch
gh run view <id> --json jobs   # startedAt / completedAt de chaque job
```

Durée d'un run (premier job démarré, dernier job terminé):

| | Runs | Min | Moyenne | Max |
|---|---|---|---|---|
| Sans le job `sonar` (pushs de branche) | 7 | 97 s | 112 s | 129 s |
| Avec le job `sonar` (PR et `main`) | 7 | 111 s | 127 s | 151 s |

Durée par job (14 runs, `sonar`: 7 runs):

| Job | Moyenne | Plage |
|---|---|---|
| test-back | 55 s | 45–63 s |
| test-front | 39 s | 21–83 s |
| build-back | 52 s | 41–59 s |
| build-front | 22 s | 14–45 s |
| sonar | 124 s | 109–151 s |

Comparaison avec la base ([`../ci-baseline/`](../ci-baseline/), 12 runs, Node 20 et Java 17, sans cache):

- **Tests et builds**: 112 s en moyenne contre 108 s, soit +4 s. L'écart est inférieur à la variabilité de la mesure
  (±8 %): pas de dégradation établie malgré Angular 22, Spring Boot 4.1 et Gradle 9.
- **Jobs front**: `test-front` passe de 54 s à 39 s et `build-front` de 39 s à 22 s en moyenne. Hypothèse non vérifiée:
  chaîne de build Angular plus rapide (builder `application` et esbuild). À confirmer avec le cache.
- **Jobs back**: `test-back` 49 s → 55 s et `build-back` 46 s → 52 s, soit environ +6 s chacun (Gradle 9 et Spring Boot 4).
- **Job `sonar`**: ajouté depuis la base. Il tourne en parallèle des autres jobs, il rallonge donc le run d'environ
  15 s en moyenne, et ne s'exécute que sur les PR et sur `main`.
- Le cache npm et Gradle reste à mesurer (backlog).

## Autres observations

- Dependabot a tourné le 18/11/2026 à 21:10 UTC (écosystèmes `docker` et `github-actions`) sans ouvrir de PR à ce
  stade. La règle `ignore` du bloc `docker` n'est pas encore confirmée.
