# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 25/11/2026**

## Où on en est

- `origin/main` à `c3572e7`. Tag `v0.0.2` (cliché intermédiaire, `docs/quality/0.0.2-components-upgraded/`).
- Fait: CI GitHub Actions, images Docker épinglées et non-root, Bulma via npm, toutes les montées de version
  (Angular 22, Spring Boot 4.1.2, Gradle 9.9.1, Java 21, Node 24, Alpine 3.24), verrou Gradle, deux bugs
  fonctionnels corrigés (liens personne/organisation, format de l'email) avec tests (PR #14).
- Sonar sur `main` (analyse du 24/11): couverture 42,2 % (lignes: back 62,7 %, front 42,1 %, `learning/` 0 %),
  21 bugs, 15 code smells, 5 vulnérabilités. Gate ERROR: `new_coverage` 30,8 % (seuil 80 %) et note de sécurité
  du code nouveau à 3 (cause probable: les 2 vulnérabilités de `learning/anki_csv.py`).
- **En cours, branche `ci/sonar-before-build`, non commité**: exclusion de `learning/**` dans Sonar, et ordre
  tests → `sonar` → build (gate non bloquant; un échec technique du scan bloque le build). YAML relu par un
  parseur seulement: à valider par la CI (push de branche: `sonar` sauté, les builds doivent tourner; PR:
  les builds doivent attendre `sonar`). L'effet de l'exclusion se lira sur l'analyse de la PR.
- Aussi non commité (présent dans le dossier de travail avant cette branche): livrables 01 et 02,
  `schema_pipeline_ci_cd.png`, `scripts/build-livrables.sh`. `docs/inputs/` (sujet et mails): non suivi,
  déconseillé dans un dépôt public.
- À mettre à jour dans les livrables: gate en échec sur deux conditions (et non la seule couverture), durée de
  référence (112 s sans `sonar`, 127 s avec, mesure `v0.0.2`), ordre tests → Sonar → build (texte et schéma).

## Prochaine étape (ordre décidé)

0. Terminer `ci/sonar-before-build` (commits, CI, PR) et commiter les livrables sur une branche `docs/…`.
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
