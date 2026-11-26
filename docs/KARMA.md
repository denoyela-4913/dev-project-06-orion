# Remplacement de Karma par Vitest: analyse et justification

État au **26/11/2026**. Tâche correspondante dans `BACKLOG.md`.

## Conclusion

**Le projet peut passer à Vitest: aucun obstacle bloquant n'a été trouvé, et Vitest est le choix recommandé.**
La migration n'est **pas encore faite** dans le dépôt. Elle a été essayée dans une copie jetable du front: les
36 tests passent, le build de production et l'image Docker du front se construisent, `npm start` répond. La CI et
l'import de la couverture dans Sonar restent à vérifier sur une vraie branche.

## Pourquoi quitter Karma

À quoi il sert ici: `ng test` lance Karma, qui ouvre Chrome et y exécute les tests écrits avec Jasmine
(`describe`, `it`, `expect`, `spyOn`).

1. **Déprécié.** Le [README du projet](https://github.com/karma-runner/karma) indique « Karma is deprecated and is
   not accepting new features or general bug fixes », sans date. Seules les failles **critiques** restent traitées,
   jusqu'à 12 mois après que le support de Web Test Runner par Angular CLI aura été déclaré stable. Dernière
   version: 6.4.4 (29/07/2024). Le paquet n'est pas marqué déprécié sur npm, et le
   [guide Angular](https://angular.dev/guide/testing/karma) le dit toujours pris en charge.
2. **Dépendances transitives dépréciées**: `inflight@1.0.6` (fuite de mémoire signalée), `rimraf@3.0.2` et
   `glob@7.2.3` (non maintenu, failles publiées), amenés par `karma` (`npm ls`). Ils concernent les tests, pas
   l'application livrée.
3. **Run interrompu** (observé le 26/11, tests de gestion d'erreurs lancés sur l'ancien code): sur des promesses
   rejetées sans traitement, `An error was thrown in afterAll`, puis `Disconnected, because no message in
   30000 ms`. 26 tests exécutés sur 36, pas de ligne `TOTAL`, code de sortie 1. La CI aurait échoué, mais avec une
   liste d'échecs incomplète. La raison de la déconnexion n'a pas été analysée. Sur le même code, Vitest exécute
   les 36 tests (18 en échec) et signale les erreurs non traitées à part.

## Contraintes examinées

| Contrainte | Constat | Bloquant |
|---|---|---|
| Compatibilité Angular | `@angular/build@22` accepte `vitest ^4.0.8 \|\| ^5.0.0`; Vitest est le lanceur par défaut des nouveaux projets Angular | non |
| Node | Vitest 5 demande `^22.12 \|\| ^24 \|\| >=26`, `jsdom` 31 au moins 24.15 sur la branche 24. Essai en local avec 24.21; image Docker construite avec l'image Node épinglée | non (CI à vérifier) |
| Builders | le lanceur `unit-test` attend `@angular/build:application`, le projet utilise `@angular-devkit/build-angular:application`. Il faut migrer le build, ce qui est déjà une tâche du backlog (builders dépréciés) | non |
| Migration « expérimentale » | Angular qualifie d'expérimentale la migration d'un projet existant et le schéma de conversion. Le code produit par le schéma **ne compilait pas** (2 types à corriger) | non: risque limité par l'essai complet |
| Code des tests | pas de `fakeAsync` ni de `waitForAsync`; les tests avec zone.js, `HttpTestingController` et lecture du DOM passent | non |
| Navigateur | par défaut, DOM simulé (`jsdom`) dans Node, au lieu de Chrome: pas de rendu ni de mise en page. Les tests actuels n'en dépendent pas. Mode navigateur possible (`@vitest/browser-playwright`, non essayé) | non, mais la fidélité baisse |
| Installation en CI et Docker | `npm ci --ignore-scripts` fonctionne, `npm audit`: 0 vulnérabilité | non |
| Sonar | le lcov sort au même chemin, `front/coverage/microcrm/lcov.info`. La liste des fichiers change: les templates HTML apparaissent | non (import à vérifier) |
| Licence | Vitest et `jsdom` sous licence MIT | non |
| Règle de versions du projet | **Vitest n'a ni LTS ni date de fin de support** ([politique](https://vitest.dev/releases)): le critère « support au-delà de 05/2027 » ne peut pas être garanti | à accepter, cf. ci-dessous |

### Règle de versions

La règle du projet (LTS avec support au-delà de 05/2027) ne peut pas s'appliquer. D'après la politique de Vitest,
les correctifs courants vont à la dernière mineure (5.1), les correctifs importants et de sécurité aussi à la
mineure précédente et à la dernière mineure de la majeure précédente (5.0 et 4.1). On propose la même règle que
pour Gradle: **viser la dernière mineure de la dernière majeure (5.1.x au 26/11) et la mettre à jour
régulièrement**. Vitest 5.0.0 date du 03/09/2026: une nouvelle majeure demandera une montée de version. Karma ne
satisfait pas non plus cette règle, et il est déprécié.

## Pourquoi Vitest est acceptable

- **Intégré à Angular**: `ng test` reste la commande; le builder `@angular/build:unit-test` n'accepte que
  `vitest` (par défaut) ou `karma`. `@angular-devkit/build-angular@22` ne fournit pas de builder Jest ni Web Test
  Runner.
- **Maintenu**: version 5.1.2 publiée le 25/11/2026, correctifs en général chaque semaine d'après le projet.
- **Plus simple à exécuter**: plus de Chrome à fournir (ni `CHROME_BIN`, ni lanceur `ChromeHeadlessNoSandbox`).
- **Moins de dépendances**: sans Karma ni `@angular-devkit/build-angular`, le verrou passe de **1014 à 530
  paquets**; `karma`, `inflight`, `rimraf` et `glob` disparaissent de l'arbre, et `npm ci` n'affiche plus
  d'avertissement de dépréciation.
- **Retour arrière possible**: tant que la branche n'est pas fusionnée, rien ne change; après, les commits de
  migration peuvent être annulés (`git revert`).

**Pas démontré: un gain de temps.** En local, Vitest avec couverture a pris 3,0 à 4,0 s sur 3 runs, Karma 3,4 à
10,1 s (le premier run était le plus long). Peu de mesures, rien en CI.

## Coût du changement

Faible, mesuré sur l'essai (36 tests, 7 fichiers, 560 lignes de tests).

| Élément | Travail |
|---|---|
| Tests à adapter | **2 fichiers sur 7**: `error-handling.spec.ts` et `person-details.component.spec.ts`, 62 lignes ajoutées et 49 supprimées hors indentation. 23 tests concernés (directement ou par leur préparation), 13 inchangés |
| Conversion | schéma `ng g @schematics/angular:refactor-jasmine-vitest`, puis à la main 2 conversions de types et 1 point signalé (`arrayWithExactContents`, remplacé par une longueur et `arrayContaining`) |
| Indentation | le schéma réindente 6 fichiers, dont 4 sans autre changement: à rétablir ou à commiter à part |
| Configuration | `angular.json` (4 builders), `package.json` (9 paquets retirés, `@angular/build`, `vitest`, `@vitest/coverage-v8` et `jsdom` ajoutés) et son verrou, `tsconfig.spec.json`, suppression de `karma.conf.js` |
| Autour | commande de test de `ci.yml`, `CLAUDE.md`, les README; livrables si nécessaire |
| Application et back | aucun changement du code de l'application; tests du back non concernés |

Le coût augmente avec les tests: chaque nouveau test qui utilise les espions de Jasmine est à convertir.

Les compteurs de couverture changent d'outil: l'essai donne 78,45 % des lignes (284/362, templates HTML compris),
Karma 74,37 % (119/160, sans les templates). **Les deux chiffres ne se comparent pas.**

## Autres pistes

Analyse rapide, **aucune n'a été essayée**. Versions et dates d'après npm; absence de builder vérifiée dans les
paquets Angular 22 installés. Les points marqués « à vérifier » ne l'ont pas été.

| Piste | Avantages | Inconvénients |
|---|---|---|
| **Jest** (30.5.2) | très répandu, projet actif, DOM simulé dans Node | pas de builder Angular: configuration à part, hors de `ng test`; pour Angular, paquet communautaire `jest-preset-angular` (17.0.3: Angular `>=20 <23`, à mettre à jour avec Angular 23); espions Jasmine à convertir |
| **Web Test Runner** (`@web/test-runner` 1.0.1) | tests dans de vrais navigateurs; cité par le README de Karma | pas de builder dans Angular 22: compilation d'Angular et des templates à mettre en place (à vérifier); compatibilité avec les tests Jasmine à vérifier |
| **jasmine-browser-runner** (5.0.0) | garde Jasmine (peu ou pas de réécriture des tests, à vérifier) et un vrai navigateur; cité par le README de Karma | pas de builder Angular: compilation des tests, templates, couverture et lcov à mettre en place et à maintenir (à vérifier); le README le cite pour les projets hors Angular |
| **Garder Karma** | aucun travail, vrai navigateur, toujours pris en charge d'après Angular | problèmes 1 et 2; migration plus chère à mesure que les tests s'ajoutent |

## Vitest reste-t-il le bon choix?

**Oui.** C'est la seule des pistes que le builder de test d'Angular 22 prend en charge, et son coût a été mesuré.
`jasmine-browser-runner` éviterait de réécrire des tests, mais déplacerait le travail vers une chaîne de
compilation propre au projet, pour économiser l'adaptation de 2 fichiers. Réserves: migration déclarée
expérimentale, pas de LTS, DOM simulé. Si les tests devaient vérifier le rendu, ajouter le mode navigateur de
Vitest.

**Quand**: proposition, après le lot 2 des issues Sonar du front et **avant le lot 3**, qui ajoutera des tests.

## Migration

Séquence essayée (les builders et la désinstallation ont été faits à la main):

1. Installer `@angular/build`, `vitest`, `@vitest/coverage-v8` et `jsdom`.
2. Lancer `ng g @schematics/angular:refactor-jasmine-vitest`, corriger les types des faux services
   (`as unknown as MockedObject<…>`) et le point signalé.
3. `angular.json`: remplacer `@angular-devkit/build-angular:` par `@angular/build:`; la cible `test` devient
   `unit-test`, avec `buildTarget`, `tsConfig` et `coverageReporters: ["text", "lcov"]`.
4. `tsconfig.spec.json`: type `vitest/globals` à la place de `jasmine`.
5. Supprimer `karma.conf.js` et désinstaller `karma`, `karma-chrome-launcher`, `karma-coverage`, `karma-jasmine`,
   `karma-jasmine-html-reporter`, `jasmine-core`, `@types/jasmine`, `istanbul-lib-instrument` et
   `@angular-devkit/build-angular`.
6. Lancer les tests avec `ng test --watch=false --coverage`.

### À vérifier sur la branche de migration

- CI: nouvelle commande de `test-front` (sans les options de navigateur), version de Node, durée.
- Sonar: import du lcov (le job `sonar` en réécrit les chemins), effet des templates HTML sur la couverture et le
  Quality Gate.
- Vérifier qu'un test volontairement cassé fait échouer la CI.
- Images Docker `standalone` et exécution du front construit (seule l'étape de construction `front` a été essayée).
- `ng extract-i18n` (builder changé, non lancé) et le mode `watch` de `ng test`.

## Essai du 26/11: ce qui a été fait

Copie du front hors du dépôt, rien n'a été commité. D'abord avec Vitest 4.1.12, puis avec **Vitest 5.1.2** et
sans Karma ni `@angular-devkit/build-angular` (`@angular/build` 22.3.0):

| Vérification | Résultat |
|---|---|
| Tests, 3 runs avec couverture | 36 sur 36 |
| Anciens composants (promesses non traitées) | 36 exécutés, 18 en échec, 7 erreurs signalées, code de sortie 1 |
| `npm ci --ignore-scripts` | 0 vulnérabilité, aucun avertissement de dépréciation |
| Build de production | 814 kB, comme avant |
| `npm start` | réponse HTTP 200, ni avertissement ni erreur dans le journal (pages non vues dans un navigateur) |
| `docker build --target front` | réussi (image non lancée) |
