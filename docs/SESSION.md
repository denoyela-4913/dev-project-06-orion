# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 26/11/2026**

## Reprise en local (relais de la session distante du 25-26/11/2026)

Résumé de la conversation (pas la transcription: le dépôt est public).

- Pour reprendre: `git fetch origin && git switch ci/sonar-before-build && git pull --ff-only`. Les modifications
  locales non commitées peuvent gêner le changement de branche: les examiner avant, sans les écraser.
- **PR de `ci/sonar-before-build`: à ouvrir** (la session distante n'avait pas d'outil GitHub, même après connexion
  du compte; `claude rc` ne permettait pas de la relier à l'ordinateur). Vérifier d'abord la CI du dernier commit.
  Base: `main` du dépôt `origin`, pas celle d'OpenClassrooms (fork): passer `--repo` à `gh pr create`.
  Titre: `ci: run sonar between tests and build`. Ne pas fusionner sans accord de l'utilisateur.
- Sur la PR, vérifier: les builds attendent `sonar`; `learning/` absent de l'analyse; Quality Gate; durée du run.
- Proposé à l'utilisateur, **pas encore décidé**: contrôles sur les branches de dev, une branche `ci/…` par ajout,
  non bloquants au début: ESLint (`angular-eslint`, `no-floating-promises`), puis `diff-cover` (couverture du code
  nouveau par rapport à `origin/main`, demande la couverture dans `test-front`), Trivy, hadolint et ShellCheck,
  puis SpotBugs. SonarQube n'exécute pas les tests: il analyse le code et importe la couverture. Ces outils
  n'ont pas été essayés sur le dépôt.

## Où on en est

- `origin/main` à `c3572e7`. Tag `v0.0.2` (cliché intermédiaire, `docs/quality/0.0.2-components-upgraded/`).
- Fait: CI GitHub Actions, images Docker épinglées et non-root, Bulma via npm, toutes les montées de version
  (Angular 22, Spring Boot 4.1.2, Gradle 9.9.1, Java 21, Node 24, Alpine 3.24), verrou Gradle, deux bugs
  fonctionnels corrigés (liens personne/organisation, format de l'email) avec tests (PR #14).
- Sonar sur `main` (analyse du 24/11): couverture 42,2 % (lignes: back 62,7 %, front 42,1 %, `learning/` 0 %),
  21 bugs, 15 code smells, 5 vulnérabilités. Gate ERROR: `new_coverage` 30,8 % (seuil 80 %) et note de sécurité
  du code nouveau à 3 (cause probable: les 2 vulnérabilités de `learning/anki_csv.py`).
- **En cours, branche `ci/sonar-before-build`, commitée et poussée, PR à ouvrir**: exclusion de
  `learning/**` dans Sonar, et ordre tests → `sonar` → build (gate non bloquant; un échec technique du scan bloque
  le build). Run de push n° 79 réussi en 2 min 01, les deux builds exécutés (`sonar` à 0 s: sauté d'après la
  condition, statut du job non affiché sur la page publique). Reste à valider sur la PR: les builds attendent
  `sonar`, effet de l'exclusion, durée. La PR #16 avait un gate ERROR avec 2 vulnérabilités et 4 code smells.
- Sonar sur branche de dev: d'après la documentation, impossible en plan Free (analyse de branche sur `main` seule);
  illimité en plan OSS. Plan de l'organisation non vérifié. Projet Sonar en visibilité publique.
- Le dépôt GitHub est public mais **pas open source au sens d'une licence**: aucun fichier de licence trouvé;
  c'est un fork d'un dépôt OpenClassrooms qui n'en affiche pas non plus.
- Livrables 01 et 02, `schema_pipeline_ci_cd.png`, `scripts/build-livrables.sh` et `docs/inputs/` (sujet, mails,
  modèles): commités sur cette branche (`8b1eed9`), ils font donc partie de la même PR. L'utilisateur a décidé de
  garder `docs/inputs/` dans le dépôt (26/11). Fichiers `*:Zone.Identifier` retirés et ignorés (`.gitignore`).
- CI de `8b1eed9` en échec (run 45718448702): `429 Too Many Requests` de Maven Central dans `test-back`.
- À mettre à jour dans les livrables: gate en échec sur deux conditions (et non la seule couverture), durée de
  référence (112 s sans `sonar`, 127 s avec, mesure `v0.0.2`), ordre tests → Sonar → build (texte et schéma).

## Prochaine étape (ordre décidé)

0. Terminer `ci/sonar-before-build` (PR).
   Puis examiner les 3 vulnérabilités CORS du back (`java:S5122`), absentes du cliché `v0.0.2`.
1. Issues Sonar du front, une branche `front/…` par lot:
   1. promesses non gérées `typescript:S9383` (16)
   2. labels de formulaire (`Web:InputWithoutLabelCheck` ×7, `Web:S6853` ×6), `<th>` du tableau (`Web:S5256`),
      `Number.parseInt` (`S7773` ×2), opération asynchrone dans le constructeur (`S7059`)
   3. tests pour monter la couverture; duplication `Organization.java` / `Person.java`
2. Jalon `v0.1.0`: tag + cliché Sonar dans `docs/quality/` (reporté après les corrections du front).
3. Puis le reste de `docs/BACKLOG.md`: remplacement de Karma, migration `@angular/build`, cache npm/Gradle,
   `sonar.java.libraries`, scan de sécurité dans la CI, étude nginx, maintenance de `ro.polak:spring-boot-data-fixtures`.

## Questions ouvertes

- GitHub au lieu de GitLab (le mail 2 demande un lien GitLab public): à confirmer avec le mentor (risque R2).
- Ancienne branche `docs/backlog-functional-bugs` (locale et distante): à supprimer? (l'utilisateur n'a pas répondu)
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
