# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 19/11/2026**

## Où on en est

- `main` à `51043d4`. Tag `v0.0.2` (cliché intermédiaire, `docs/quality/0.0.2-components-upgraded/`).
- Fait: CI GitHub Actions, images Docker épinglées et non-root, Bulma via npm, toutes les montées de version
  (Angular 22, Spring Boot 4.1.2, Gradle 9.9.1, Java 21, Node 24, Alpine 3.24), verrou Gradle, deux bugs
  fonctionnels corrigés (liens personne/organisation, format de l'email) avec tests (PR #14).
- Aucun travail de code en cours: la prochaine session part de `main` à jour et crée une branche.
- Sonar: le gate de la PR #14 est OK (couverture du code nouveau 100 %). Le gate de `main` était en échec avant
  cette PR pour `new_coverage` = 0 %; à relire sur l'analyse de `main` après la fusion de la PR #14.

## Prochaine étape (ordre décidé)

1. Issues Sonar du front, une branche `front/…` par lot:
   1. promesses non gérées `typescript:S9383` (16)
   2. labels de formulaire (`Web:InputWithoutLabelCheck` ×7, `Web:S6853` ×6), `<th>` du tableau (`Web:S5256`),
      `Number.parseInt` (`S7773` ×2), opération asynchrone dans le constructeur (`S7059`)
   3. tests pour monter la couverture; duplication `Organization.java` / `Person.java`
2. Jalon `v0.1.0`: tag + cliché Sonar dans `docs/quality/` (reporté après les corrections du front).
3. Puis le reste de `docs/BACKLOG.md`: remplacement de Karma, migration `@angular/build`, cache npm/Gradle,
   `sonar.java.libraries`, scan de sécurité dans la CI, étude nginx, maintenance de `ro.polak:spring-boot-data-fixtures`.

## Questions ouvertes

- Ancienne branche `docs/backlog-functional-bugs` (locale et distante): à supprimer? (l'utilisateur n'a pas répondu)
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
