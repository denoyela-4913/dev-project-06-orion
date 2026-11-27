# Les tests d'Orion

## La pyramide

| Niveau | Vitesse | Ce qu'il prouve | Outils |
|---|---|---|---|
| unitaire | millisecondes | une unité fait ce qu'elle doit | Vitest, JUnit |
| intégration | secondes | des composants s'assemblent (base, contrôleurs) | `@DataJpaTest`, MockMvc |
| fonctionnel | secondes | un scénario d'API aboutit, par HTTP réel | `@SpringBootTest` sur un port |
| bout en bout (**e2e**, *end to end*) | dizaines de secondes | un parcours utilisateur marche dans un navigateur | Playwright |
| déploiement (*smoke test*) | secondes | l'instance déployée répond | `smoke_test.sh` |

Plus on monte, plus c'est réaliste, lent et fragile : beaucoup de tests en bas, peu en haut.

## Pièges et règles

| Piège | Règle |
|---|---|
| un test qui n'a jamais échoué | l'écrire d'abord, le voir échouer, puis corriger |
| relancer jusqu'au vert | aucun nouvel essai automatique : on corrige l'instabilité |
| des tests qui dépendent des précédents | chaque test crée ses données (suffixe propre à l'exécution) |
| Vitest garde les espions d'un test à l'autre | les restaurer après chaque test (`test-setup.ts`) |

> **Exemple vécu.** Le bouton « + » réagissait au clic sur son texte, pas au clavier. Un test unitaire (clic sur le
> bouton) et un test de bout en bout (touche Entrée) le détectent.

## Les tests de bout en bout d'Orion

Cinq parcours : données de démonstration, cycle de vie d'une personne, lien personne-organisation au clavier,
adresse e-mail refusée, API indisponible. Une erreur JavaScript de la page fait échouer le test.

## Dans Orion

[`docs/TESTS.md`](../../docs/TESTS.md), [`e2e/tests/`](../../e2e/tests/),
[`ApiScenarioTests.java`](../../back/src/test/java/com/openclassroom/devops/orion/microcrm/ApiScenarioTests.java),
[`scripts/test_recovery.sh`](../../scripts/test_recovery.sh).

## À retenir

1. Un cas se teste au niveau le plus bas qui peut le prouver.
2. Les secours se testent aussi : une sauvegarde jamais restaurée n'est pas une sauvegarde.
