# Rapport SonarQube après le passage au scan CI

Cliché de la branche `main` analysée par le job `sonar` de la CI (`sonarqube-scan-action`, avec couverture), au
commit `d3982e6`, le 18/11/2026. Il remplace l'analyse automatique utilisée pour l'état initial
([`../0.0.1-initial-state/`](../0.0.1-initial-state/)).

Le code applicatif (front et back) est le même que dans l'état initial: seuls la méthode d'analyse et les fichiers de CI
diffèrent. Ce cliché est donc la base de comparaison à utiliser pour les mesures futures.

Commandes utilisées (depuis la racine du dépôt):

```bash
scripts/sonar-export.sh -b main -o docs/quality/sonar-ci-scan-baseline
curl -s "https://sonarcloud.io/api/measures/component_tree?component=<clé du projet>&branch=main&metricKeys=coverage,line_coverage,lines_to_cover,uncovered_lines,conditions_to_cover,uncovered_conditions&qualifiers=FIL&ps=200&strategy=leaves" \
  > docs/quality/sonar-ci-scan-baseline/sonar-main-coverage-by-file.json
```

Relancer ces commandes donne l'état courant de `main`, pas celui de ce cliché.

## Comparaison avec l'état initial

| Mesure | État initial (analyse automatique) | Scan CI (ce cliché) |
|---|---|---|
| Issues | 35 | 39 |
| Vulnérabilités | 6 | 6 (les mêmes) |
| Bugs | 20 | 24 |
| Code smells | 9 | 9 |
| Sécurité / Fiabilité / Maintenabilité | C / C / A | C / C / A |
| Quality Gate de `main` | non calculé | OK |
| Couverture | non mesurée | 37,1 % (lignes: 40,6 %) |
| Duplication | 0,0 % | 1,7 % |
| Lignes de code (ncloc) | 1 010 | 1 286 |

Les 35 issues de l'état initial sont toutes retrouvées, aucune n'a disparu: le périmètre analysé est le même.

## Pourquoi 39 issues au lieu de 35

Les 4 issues supplémentaires sont des `typescript:S9383` (promesse non gérée) sur des appels `this.router.navigate(...)`:

- `organization-details.component.ts`, lignes 51 et 59;
- `person-details.component.ts`, lignes 57 et 65.

Ce code n'a pas changé depuis `v0.0.1`. L'explication la plus probable (non vérifiée par un test) est que le scan de la CI
a les dépendances installées (`npm ci`) et connaît donc le type de retour de `navigate()`, une promesse, ce que
l'analyse automatique, sans `node_modules`, ne pouvait pas voir. L'analyse est plus précise, le code n'est pas
dégradé. Pour la même base de code, l'état initial se lit donc 35 issues avec l'ancienne méthode et 39 avec la nouvelle.

Autres différences, dues à la méthode ou aux fichiers ajoutés depuis:

- **Lignes de code**: +276, en grande partie les fichiers ajoutés depuis (workflow, scripts, configuration).
- **Duplication 1,7 %**: 14 lignes dupliquées dans chacun de `Organization.java` et `Person.java` (code existant).
  Pourquoi la mesure initiale affichait 0,0 % n'est pas établi.

## Couverture de départ

| Zone | Lignes à couvrir | Non couvertes | Couverture (lignes) |
|---|---|---|---|
| Back | 70 | 28 | 60,0 % |
| Front | 122 | 86 | 29,5 % |
| Total | 192 | 114 | 40,6 % |

Le chiffre global de 37,1 % de Sonar inclut aussi les conditions (branches), d'où l'écart avec les 40,6 % de lignes.
Le détail par fichier est dans `sonar-main-coverage-by-file.json`.

## Limite connue

Le scanner générique ne connaît pas le classpath Gradle (`Missing 'sonar.java.libraries'`): l'analyse Java est un peu moins
précise qu'avec le plugin Gradle de Sonar. Cette amélioration est au backlog.
