# Karma: problèmes constatés et pistes de remplacement

État au **26/11/2026**. La tâche correspondante est dans `BACKLOG.md`. Rien n'est décidé ni essayé pour le
remplacement.

## À quoi sert Karma ici

`ng test` lance Karma (`karma@6.4.4`), qui ouvre Chrome et y exécute les tests écrits avec Jasmine:

- **Karma** lance le navigateur et remonte les résultats;
- **Jasmine** est la bibliothèque de test (`describe`, `it`, `expect`, `spyOn`).

Fichiers concernés: `front/karma.conf.js`, la cible `test` de `front/angular.json`
(`@angular-devkit/build-angular:karma`), `front/tsconfig.spec.json`, le job `test-front` de la CI. La couverture
est écrite dans `front/coverage/microcrm/lcov.info`, lue par Sonar.

## Problème 1: Karma est déprécié

- Le README du projet indique: « Karma is deprecated and is not accepting new features or general bug fixes. » Il ne
  donne pas de date. Les failles de sécurité **critiques** restent traitées, jusqu'à 12 mois après que le support
  de Web Test Runner par Angular CLI aura été déclaré stable
  ([README](https://github.com/karma-runner/karma)).
- La dernière version est la 6.4.4 (publiée le 29/07/2024, `npm view karma time`). `npm view karma@6.4.4 deprecated`
  ne renvoie rien: le paquet n'est pas marqué déprécié sur npm, l'annonce est dans le dépôt.
- Côté Angular, [le guide Karma](https://angular.dev/guide/testing/karma) le dit toujours pris en charge, tandis que
  Vitest est le lanceur par défaut des **nouveaux** projets.

Conséquence: pas d'urgence démontrée, mais les défauts qui ne sont pas des failles critiques ne seront pas corrigés.

## Problème 2: dépendances transitives dépréciées

`npm ci` affiche des `npm warn deprecated`. D'après `npm ls karma glob rimraf inflight` (26/11):

| Paquet | Amené par | Message de npm (résumé) |
|---|---|---|
| `inflight@1.0.6` | `karma` → `glob@7.2.3` | non maintenu, fuite de mémoire |
| `rimraf@3.0.2` | `karma` | versions antérieures à la 4 non maintenues |
| `glob@7.2.3` | `karma` et `rimraf` | ancienne version non maintenue, failles de sécurité publiées |

- Dans cet arbre, ils viennent de `karma@6.4.4`: ils concernent les tests, pas l'application livrée.
- `npm audit` signalait 0 vulnérabilité après les montées de version (cf. « Fait » dans le backlog; non relancé le
  26/11), malgré l'avertissement de `glob`.
- Forcer des versions récentes avec `overrides` n'est pas testé par Karma: piste écartée.

## Problème 3: un run interrompu masque une partie des résultats

Observé le 26/11 en lançant les nouveaux tests de gestion d'erreurs sur l'ancien code des composants, qui ne
traitait pas les promesses rejetées:

```text
An error was thrown in afterAll
Error: API down
...
Disconnected , because no message in 30000 ms.
Executed 26 of 36 (10 FAILED) DISCONNECTED
```

- 10 tests sur 36 n'ont pas été exécutés et la ligne `TOTAL` manque. Le code de sortie est 1: la CI aurait bien
  échoué, mais la liste des échecs est incomplète.
- Une sortie filtrée sur les échecs ressemblait à un résultat complet. **Comparer le nombre de tests exécutés au
  nombre attendu.**
- Pour prouver que chaque test échouait, il a fallu lancer les groupes séparément (`fdescribe` temporaire).
  Chaque groupe lancé ainsi s'est aussi terminé par une déconnexion.
- Avec le code corrigé, trois runs de suite: 36 sur 36, sans déconnexion.

**Cause**: le point de départ est dans le code testé (les promesses rejetées sans traitement, `Error: API down`
vient du test). La raison de la déconnexion qui suit n'a pas été analysée, et rien ne montre qu'elle soit propre à
Karma: le même cas n'a pas été essayé avec un autre lanceur. Ce n'est donc pas, à lui seul, un argument pour le
remplacer.

## Contrainte liée: les builders dépréciés

La cible `test` utilise `@angular-devkit/build-angular:karma`. `npm start` signale que ce paquet est déprécié pour
`dev-server` au profit de `@angular/build`. La migration des builders (autre tâche du backlog) est liée à celle-ci.

## Pistes de remplacement

| Piste | Exécution | Pour | Contre ou à vérifier |
|---|---|---|---|
| **Vitest** (`@angular/build:unit-test`) | Node avec DOM simulé (`jsdom` ou `happy-dom`) par défaut; vrai navigateur en option (`@vitest/browser-playwright`) | lanceur par défaut des nouveaux projets Angular, guide de migration et schéma de conversion | migration d'un projet existant et schéma déclarés **expérimentaux** par Angular |
| **Jest** | Node | cité par le README de Karma parmi les alternatives | absent des pages Angular consultées: intégration à vérifier |
| **Web Test Runner** | navigateur | cité par le README de Karma | absent des pages Angular consultées: support par Angular CLI à vérifier |
| **jasmine-browser-runner** | navigateur | cité par le README de Karma, garde Jasmine | cité pour les projets hors Angular: intégration à vérifier |
| **Garder Karma** pour l'instant | navigateur (comme aujourd'hui) | aucun travail, toujours pris en charge d'après Angular | les problèmes 1 et 2 restent |

**Proposition (non décidée)**: évaluer d'abord Vitest dans une branche `front/…`, à cause de son intégration
documentée par Angular, avec la possibilité de rester sur Karma si l'essai n'est pas concluant.

### Étapes de la migration vers Vitest, d'après la documentation Angular (non essayées)

Sources: [guide de migration](https://angular.dev/guide/testing/migrating-to-vitest),
[couverture](https://angular.dev/guide/testing/code-coverage). Pré-requis: le système de build `application`
(le build du projet l'utilise déjà).

1. Installer `vitest` et `jsdom`, plus `@vitest/coverage-v8` pour la couverture.
2. Dans `angular.json`, remplacer le builder de `test` par `@angular/build:unit-test`. Les options de build
   (`polyfills`, `assets`, `styles`) passent dans une configuration de build.
3. Reporter les réglages utiles de `karma.conf.js`, puis le supprimer et désinstaller les paquets `karma*` et
   `jasmine-core`.
4. Convertir les tests: `ng g @schematics/angular:refactor-jasmine-vitest`. Le schéma peut ne pas couvrir tous
   les cas, et ne modifie ni les paquets ni `angular.json`.
5. Couverture: ajouter `lcov` à `coverageReporters`.

### Points à vérifier pendant l'essai

- **Sonar**: la documentation ne précise pas le chemin du fichier lcov. Le relever, puis adapter
  `sonar.javascript.lcov.reportPaths` et les artefacts de `ci.yml`, puis comparer la couverture avant et après
  (l'outil de mesure change).
- **Conversion**: les tests utilisent les espions de Jasmine, surtout `src/app/error-handling.spec.ts`
  (`createSpyObj`, `callFake`, `resolveTo`, `arrayWithExactContents`).
- **zone.js**: l'application utilise la détection de changements avec zone.js; vérifier le comportement des tests.
- **DOM simulé ou navigateur**: certains tests lisent le DOM et remplissent des champs. Choisir le mode et
  vérifier que les résultats restent significatifs.
- **CI**: remplacer `--code-coverage --browsers=ChromeHeadlessNoSandbox` et mesurer la durée de `test-front`.
- **Erreurs non traitées**: vérifier qu'un rejet non traité fait échouer le run et que tous les tests s'exécutent.
- **Documentation**: mettre à jour les commandes de `CLAUDE.md` et du README.
