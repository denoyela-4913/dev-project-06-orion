# Rapport SonarQube de l'état initial

Cliché de l'analyse SonarQube Cloud de la branche `main` au commit `5f06502` (code du tag `v0.0.1`),
pris le 18/11/2026.

Commande utilisée pour produire les JSON (depuis la racine du dépôt):

```bash
scripts/sonar-export.sh -b main -o docs/quality/0.0.1-initial-state
```

Relancer cette commande donne l'état **courant** de `main`, pas celui du tag: les fichiers de ce dossier
restent la référence de l'état initial.
