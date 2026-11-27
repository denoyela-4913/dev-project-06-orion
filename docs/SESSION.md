# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 27/11/2026**

## Priorité et mandat

- **Priorité de l'utilisateur (26/11)**: sécurité et accélération de la CI.
- **Mandat de nuit (du 26/11 au soir au 27/11 avant 06h00)**: réalisé, état détaillé et vérifications dans
  [`docs/AUDIT-2026-11-27.md`](AUDIT-2026-11-27.md). L'autorisation de commiter et fusionner valait pour ce mandat
  seulement: **la redemander désormais**.

## En attente d'une décision de l'utilisateur

Détail dans le backlog: hébergement (environnement permanent, état Terraform distant, sauvegardes); protection de
l'API; protection de `main`; Quality Gates Sonar bloquants; base de données de production; canal de notification;
format de téléphone; ordre ou parallélisme du job `lint`; sort de `.gitlab-ci.yml`.

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
- L'API n'a pas d'authentification (CORS n'est pas un contrôle d'accès): tâche ajoutée au backlog, non décidée
  (PR #23).
- PR #24 fusionnée en rebase le 26/11 (`86b9306`): lot 1 du front, promesses non gérées, détail dans le backlog.
  Les échecs d'enregistrement, de suppression, d'ajout et de retrait sont vérifiés par les tests seulement.
  Analyse de `main` (run 45853142065): gate OK, 0 `typescript:S9383` (13 avant), 8 bugs (21 avant), 11 code
  smells, 0 vulnérabilité, couverture 69,6 % (50,4 % avant), duplication 1,4 %.
- Couverture au même moment (Sonar): front 70,4 %, back 67,9 %. Envoyée à Sonar, mais ne bloque pas la CI: aucun
  seuil local trouvé, le scan n'attend pas le Quality Gate (80 % sur le code nouveau), et `main` n'est pas protégée.
  Exclusions de couverture envisagées (`karma.conf.js`, fichiers de démarrage): non décidées.
- Karma → Vitest (décidé le 26/11, versions suivies comme pour Gradle): migration sur la branche
  `front/migrate-to-vitest`, avec les builders `@angular/build`; justification et vérifications dans
  `docs/KARMA.md`. PR #26 fusionnée (`0566d3a`): gate OK, couverture 75,8 % (69,6 % avant).
- Défauts d'affichage et de navigation relevés pendant le lot 1: ajoutés au backlog, priorité non décidée.
- `back/bin/` (sortie de compilation de l'IDE) n'est plus suivi par git et est ignoré (26/11):
  `bin/main/application.properties`, versionné depuis le commit initial, apparaissait modifié à chaque recopie de la
  source. Dans un dossier où il est encore modifié: `git restore back/bin/main/application.properties` avant de
  mettre `main` à jour (git supprime alors le fichier; l'IDE le recrée, ignoré).
- Dépôt fork: sur ce poste, le dépôt par défaut de `gh` est celui d'`origin` (`gh repo set-default --view`, vérifié
  le 26/11, PR #30): `--repo` n'est pas nécessaire. Le passer à `gh pr create` sur un poste sans ce réglage, pour ne
  pas viser le dépôt d'OpenClassrooms.
- Trois projets Sonar (`_front`, `_back`, `_infra`) et trois scans parallèles depuis la PR #33 (26/11, détail et
  mesures dans le backlog, « Fait »): run de `main` 131 s, gates OK sur la PR. L'ancien projet unique n'est plus analysé.
  `scripts/sonar-export.sh -p front|back|infra` exporte un projet; `scripts/sonar-export-release.sh <tag>` les trois
  d'un coup (jalon `v0.1.0`: créer le tag, attendre la CI de `main`, lancer le script). À revérifier: statut du gate sur la branche `main`
  des nouveaux projets (non affiché par l'API juste après la première analyse); un cliché `docs/quality/` par projet
  pour le jalon `v0.1.0`.
- Livrables mis à jour le 26/11 pour les trois projets Sonar, les seuils de couverture (job `coverage`) et Vitest.
- Un commit de documentation (`ae078c6`) a été poussé par erreur dans la branche `back/dedupe-entities` (PR #32,
  fusionnée): l'autre session avait changé de branche dans le dossier partagé. Doublon sans effet sur `main`.
  Travailler dans un worktree (`git worktree add`) quand deux sessions utilisent le même dossier.
- Issues Sonar du front, lots 2 et 3 terminés le 26/11, détail dans le backlog: PR #30 (labels, `<th>`,
  `Number.parseInt`, `ngOnInit`), PR #32 (duplication `Person` / `Organization`), PR #37 (fichiers de démarrage
  d'Angular exclus de la couverture, décidé le 26/11), PR #39 (tests des services du front).
- `main` après la PR #39 (`9614697`, run 45902475261 vert), gates OK pour les trois projets: front 97,6 % de
  couverture et 0 code smell; back 93,9 % et 2 code smells (`java:S6813`); infra 0 code smell. Pour les trois:
  0 bug, 0 vulnérabilité, 0 hotspot, 0 % de duplication.
- Après la fusion des PR du front, relancer `npm ci --ignore-scripts` si les `node_modules` datent d'avant Vitest.
- Vu une fois le 26/11, machine très chargée (charge moyenne autour de 57): `ng test --coverage` en échec
  (`Timeout waiting for worker to respond`, aucun test exécuté). Réussi ensuite, charge retombée.

- **Nuit du 26 au 27/11** (PR #43 à #56, toutes fusionnées en rebase): pipeline CI/CD complet du schéma
  (lint, Checkstyle et SpotBugs, images et Compose, Trivy, Helm, Terraform, release, déploiement de démonstration,
  secours, notification), tests fonctionnels et de bout en bout, fiches et flashcards. Versions publiées:
  `v0.1.0` à `v0.2.2`; cliché Sonar `docs/quality/v0.1.0/`. Bilan, preuves et réserves:
  [`docs/AUDIT-2026-11-27.md`](AUDIT-2026-11-27.md).

## Prochaine étape (proposée, non décidée)

1. Prendre les décisions ci-dessus, en commençant par la sécurité (API, `main`).
2. Corriger les 7 vulnérabilités moyennes des images (backlog).
3. Accélération: détection Gradle du scan `sonar-back` (31 s), cache des couches Docker.

Seuils de couverture: 80 % pour le front et pour le back, tout le code et code nouveau, **bloquants**. Sonar ne
compte pas les templates HTML.

## Questions ouvertes

- GitHub au lieu de GitLab (le mail 2 demande un lien GitLab public): à confirmer avec le mentor (risque R2).
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
- Branches supprimées le 26/11 au soir (demande d'un dépôt sans branche qui traîne; `git branch <nom> <sha>` pour
  restaurer tant que git conserve le commit): `docs/backlog-functional-bugs` (`4f0ac28`, ses deux bugs sont corrigés
  depuis la PR #14), `ci/blocking-coverage` (`d777b45`, PR #41 fermée, remplacée par la #42),
  `docs/learning-devops-outils` (`dc8170a`) et `docs/quality-sonar-ci-baseline` (`1aa359f`), déjà intégrées à `main`.
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
