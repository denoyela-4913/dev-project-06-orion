# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 26/11/2026**

## Propositions en attente

- **Pas encore décidé**: contrôles sur les branches de dev, une branche `ci/…` par ajout, non bloquants au début:
  ESLint (`angular-eslint`, `no-floating-promises`), puis `diff-cover` (couverture du code nouveau par rapport à
  `origin/main`, demande la couverture dans `test-front`), Trivy, hadolint et ShellCheck, puis SpotBugs. SonarQube
  n'exécute pas les tests: il analyse le code et importe la couverture. Ces outils n'ont pas été essayés sur le dépôt.
- **Pas encore décidé**: rendre le Quality Gate bloquant (`sonar.qualitygate.wait=true`), dans une branche `ci/…`.
  Le gate de `main` est maintenant vert; le commentaire de `ci.yml` qui justifie le gate non bloquant par son
  échec est à corriger.

## Où on en est

- Tag `v0.0.2` (cliché intermédiaire, `docs/quality/0.0.2-components-upgraded/`).
- Fait: CI GitHub Actions, images Docker épinglées et non-root, Bulma via npm, toutes les montées de version
  (Angular 22, Spring Boot 4.1.2, Gradle 9.9.1, Java 21, Node 24, Alpine 3.24), verrou Gradle, deux bugs
  fonctionnels corrigés (liens personne/organisation, format de l'email) avec tests (PR #14).
- PR #17 fusionnée en rebase le 26/11 (`63724d1`): `learning/**` exclu de Sonar, ordre tests → `sonar` → build
  (gate non bloquant; un échec technique du scan bloque le build). Vérifié sur la PR: les builds attendent `sonar`,
  `learning/**` figure dans les exclusions du scan, Quality Gate réussi avec 0 nouvelle issue.
- Durée des runs avec cet ordre: PR 246 s (run 45719775318), `main` 295 s (run 45767726242, dont `sonar` 171 s).
  Référence `v0.0.2`: 127 s avec `sonar` en parallèle.
- Sonar sur `main` après la PR #17: Quality Gate **OK** (`new_coverage` 92,3 %), couverture 47,1 %, duplication
  1,5 %, 21 bugs, 11 code smells, 3 vulnérabilités (les 3 `java:S5122` CORS du back). La cause de la hausse de
  `new_coverage` (30,8 % au 24/11) n'a pas été vérifiée.
- Sonar sur branche de dev: d'après la documentation, impossible en plan Free (analyse de branche sur `main` seule);
  illimité en plan OSS. Plan de l'organisation non vérifié. Projet Sonar en visibilité publique.
- Le dépôt GitHub est public mais **pas open source au sens d'une licence**: aucun fichier de licence trouvé;
  c'est un fork d'un dépôt OpenClassrooms qui n'en affiche pas non plus.
- Livrables 01 et 02, `schema_pipeline_ci_cd.png`, `scripts/build-livrables.sh` et `docs/inputs/` (sujet, mails,
  modèles) sont dans `main`. L'utilisateur a décidé de garder `docs/inputs/` dans le dépôt (26/11). Fichiers
  `*:Zone.Identifier` retirés et ignorés (`.gitignore`).
- PR #19 fusionnée en rebase le 26/11 (`770a887`): `sonar` réutilise les résultats des jobs de tests (artefacts).
  Analyse complète de `main` (run 45780226856): gate OK, 21 bugs, 11 code smells, 3 vulnérabilités, couverture
  47,1 %, duplication 1,5 %, soit les mêmes totaux qu'avant (issues non comparées une par une). Durée du run: 200 s
  (`sonar` 83 s), contre 295 s après la PR #17.
- `429 Too Many Requests` de Maven Central, vu trois fois: runs 45718448702, 45772345591 et 45806595627 (premier
  run du cache, encore vide; la relance a réussi). Cache Gradle ajouté (PR #21): limite les téléchargements, sans
  supprimer le risque quand le cache est vide ou périmé.
- PR #22 fusionnée en rebase le 26/11 (`becf10b`): CORS du back limité aux origines du front, détail dans le
  backlog. Vérifié avec curl sur le jar, pas dans un navigateur. Analyse de `main` (run 45809708667, 181 s): gate
  OK, 0 vulnérabilité (3 avant), 0 hotspot, 21 bugs, 11 code smells, couverture 50,4 % (47,1 % avant), duplication
  1,5 %. Commande Gradle avec cache sur ce run: 25 s (`test-back`) et 20 s (`build-back`).
- L'API n'a pas d'authentification (CORS n'est pas un contrôle d'accès): tâche ajoutée au backlog, non décidée.
- `back/bin/main/application.properties` est suivi par git et s'est trouvé modifié localement (probablement par
  l'IDE, non vérifié): restauré sans être commité. Retrait du suivi non décidé.
- Dépôt fork: passer `--repo` (dépôt d'`origin`) à `gh pr create`, pour ne pas viser le dépôt d'OpenClassrooms.
- À mettre à jour dans les livrables: état du gate (vert sur `main` depuis le 26/11), durées de référence
  (112 s sans `sonar`, 127 s avec, mesure `v0.0.2`; puis les mesures ci-dessus), ordre tests → Sonar → build
  (texte et schéma).

## Prochaine étape (ordre décidé)

1. Issues Sonar du front, une branche `front/…` par lot:
   1. promesses non gérées `typescript:S9383` (13 sur `main` au 26/11)
   2. labels de formulaire (`Web:InputWithoutLabelCheck` ×7, `Web:S6853` ×6), `<th>` du tableau (`Web:S5256`),
      `Number.parseInt` (`S7773` ×2), opération asynchrone dans le constructeur (`S7059`)
   3. tests pour monter la couverture; duplication `Organization.java` / `Person.java`
2. Jalon `v0.1.0`: tag + cliché Sonar dans `docs/quality/` (reporté après les corrections du front).
3. Puis le reste de `docs/BACKLOG.md`: remplacement de Karma, migration `@angular/build`, cache npm,
   `sonar.java.libraries`, 2 `java:S6813` (`InitialDataFixture.java`), scan de sécurité dans la CI, étude nginx, maintenance de `ro.polak:spring-boot-data-fixtures`.

## Questions ouvertes

- GitHub au lieu de GitLab (le mail 2 demande un lien GitLab public): à confirmer avec le mentor (risque R2).
- Ancienne branche `docs/backlog-functional-bugs` (locale et distante): à supprimer? (l'utilisateur n'a pas répondu)
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
