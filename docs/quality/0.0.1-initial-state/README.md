# Rapport SonarQube de l'état initial

Cliché de l'analyse SonarQube Cloud de la branche `main` au commit `5f06502` (code du tag `v0.0.1`),
pris le 18/11/2026.

Commande utilisée pour produire les JSON (depuis la racine du dépôt):

```bash
scripts/sonar-export.sh -b main -o docs/quality/0.0.1-initial-state
```

Relancer cette commande donne l'état **courant** de `main`, pas celui du tag: les fichiers de ce dossier
restent la référence de l'état initial.

Ce cliché a été pris avec l'**analyse automatique** de SonarQube Cloud (sans dépendances installées, sans couverture de
tests). Depuis, l'analyse est lancée par la CI. Pour la même base de code, le scan CI voit 4 issues de plus (39 au
lieu de 35) et mesure la couverture: voir [`../sonar-ci-scan-baseline/`](../sonar-ci-scan-baseline/), à utiliser comme
base de comparaison pour les mesures futures.
