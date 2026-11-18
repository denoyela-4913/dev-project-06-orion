# Mesure de performance de la CI (sans cache)

Base de référence des durées du workflow `CI` ([ci.yml](../../../.github/workflows/ci.yml)), relevée le
18/11/2026 sur les 12 runs de la branche `ci/github-actions` (tous en succès). Aucun cache npm ni Gradle n'est
activé à ce stade: cette mesure sert de point de comparaison avant l'ajout du cache (voir le backlog).

Commandes utilisées:

```bash
gh run list --limit 30 --json databaseId,event,conclusion,createdAt,updatedAt
gh run view <id> --json jobs --jq '.jobs[] | {name, startedAt, completedAt}'
```

## Durée totale d'un run

| Min | Moyenne | Max |
|-----|---------|-----|
| 99 s | 108 s | 116 s |

Les runs `push` et `pull_request` ont des durées équivalentes.

## Durée par job (12 runs)

| Job | Moyenne | Plage |
|-----|---------|-------|
| test-front | 54 s | 41–66 s |
| test-back | 49 s | 42–56 s |
| build-back | 46 s | 40–53 s |
| build-front | 39 s | 33–45 s |

## Lecture

- Les deux builds ont `needs: [test-front, test-back]`: le chemin critique est séquentiel,
  soit environ max(tests) + max(builds) ≈ 54 + 46 ≈ 100 s, plus l'attente des runners.
- Chaque job repart de zéro (installation npm, téléchargement Gradle): c'est le gain potentiel du cache.
- Variabilité du total: environ ±8 %. Un gain inférieur à 10 s serait difficile à distinguer du bruit.
