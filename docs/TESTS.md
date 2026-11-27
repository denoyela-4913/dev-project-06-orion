# Stratégie de test

## Niveaux

| Niveau | Outil | Contenu | Où | Job de CI |
|---|---|---|---|---|
| Unitaires front | Vitest, jsdom | composants, services, messages d'erreur, états d'affichage, accessibilité de base | `front/src/**/*.spec.ts` | `test-front` |
| Unitaires et intégration back | JUnit, `@DataJpaTest`, MockMvc | entités, dépôts, validation, CORS, sondes de santé | `back/src/test/java` | `test-back` |
| Fonctionnels back | `@SpringBootTest` sur un port réel, client HTTP | scénarios de l'API avec les appels du front : cycle de vie, liens, suppression, refus | `ApiScenarioTests` | `test-back` |
| Bout en bout | Playwright, Chromium | l'application assemblée (front, proxy, back) pilotée dans un navigateur | `e2e/tests` | `e2e` |
| Déploiement | `scripts/smoke_test.sh` | santé, routes, API, écriture, refus d'une origine étrangère | – | `compose-test`, `staging`, production |
| Secours | `scripts/test_recovery.sh` | restauration, annulation, retour arrière | – | `staging` |
| Scripts | `unittest` | couverture (`coverage_gate.py`), version et notes (`release.py`), lancement des conteneurs et construction des images | `scripts/test_*.py` | `coverage` |
| Terraform | `terraform test` (fournisseur simulé) | garde-fous du module `platform` | `modules/platform/tests` | `infra-check` |

Dans la CI, les tests du front et du back tournent dans l'étape de compilation du `Dockerfile`
(`scripts/ci_test.sh <front|back>`, lançable sur un poste avec Docker seul). Pour le back, `./gradlew check` lance
aussi Checkstyle et SpotBugs ; leurs rapports sont importés dans Sonar, y compris après un échec.

## Lancer les tests

```bash
cd back && ./gradlew clean build                     # unitaires, fonctionnels, Checkstyle, SpotBugs
cd front && npx ng test --watch=false --coverage
python3 -m unittest discover -s scripts
scripts/compose.sh dev up -d --build --wait && scripts/e2e.sh && scripts/compose.sh dev down
```

Les tests de bout en bout n'ont besoin que de Docker : le navigateur est dans l'image de Playwright. En cas
d'échec, la CI publie le rapport et les traces (artefact `e2e-report`).

## Couverture

Seuils **bloquants** : 80 % pour le front et pour le back, sur tout le code et sur le code nouveau (job `coverage`,
`scripts/coverage_gate.py`). La couverture vient des tests unitaires et fonctionnels ; les tests de bout en bout
n'y comptent pas. Sonar ignore les templates HTML.

Ce que la couverture ne mesure pas : la justesse des assertions. Règle du projet : tout correctif a un test qui
échoue sans lui.

## Principes

- Un test de bout en bout par parcours utilisateur, pas par cas : les cas se vérifient plus bas, plus vite.
- Pas de nouvel essai automatique : un test instable est un défaut à corriger.
- Les tests de bout en bout créent leurs données avec un suffixe propre à l'exécution.

## Non couvert

Tests de charge et de performance, accessibilité complète (au-delà des règles ESLint sur les templates et des
libellés), compatibilité d'autres navigateurs que Chromium : voir `docs/BACKLOG.md`.
