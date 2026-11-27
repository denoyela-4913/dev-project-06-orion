# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 28/11/2026**

## Dernier lot: un script par job (PR #66, 28/11)

Chaque job rejouable de `ci.yml` lance `scripts/ci/<job>.sh`, que `ci_local.sh <job>` lance aussi (les anciennes
étapes `test`, `infra` et `compose` n'existent plus). Vérifié: `ci_local.sh all` sur le poste; les deux chemins de
`ci/staging.sh` sur des runners GitHub (minikube, et « version prévue » avec les empreintes de `v0.2.4`, run
46080588509). L'autorisation de fusionner valait pour ce lot: **la redemander**. Reste possible: essais réels des
scripts des développeurs (`app.sh`, `run_*.sh`, Helm), que la CI ne joue pas.

## Lot précédent: documentation et scripts (27/11)

- PR #59 à #62: `standalone` supprimée, images construites à partir des artefacts des tests, jobs de build supprimés,
  Checkstyle et SpotBugs dans `test-back` et dans Sonar, `v0.2.4` **promue**, retours arrière essayés.
- PR #63: schéma et livrables.
- PR #64: lancement manuel de la CI, ShellCheck, `ci_local.sh`, `app.sh`, Helm sur minikube. CI locale complète
  réussie sur le poste (hors staging sur cluster); minikube validé sur un runner GitHub (run 46070319151), pas sur le
  poste; lancement manuel réussi sur `main` (run 46072510868), sans publication.
- Ménage du 27/11, après comparaison avec `main` (rien à récupérer): worktrees `../orion-staging-wt` et
  `../orion-artefacts-wt` et 8 branches locales supprimés; dossier principal remis sur `main`. Sauvegarde des
  modifications non commitées et des branches, hors du dépôt: `../orion-sauvegarde-menage-2026-11-27/` (à supprimer
  quand l'utilisateur n'en a plus besoin).
- Les autorisations de commiter et fusionner valaient pour ces lots seulement: **les redemander**.
- À décider: promotion capable de mettre à niveau la production (backlog). Reste aussi la justification de Caddy.

## Priorité et mandat

- **Priorité de l'utilisateur (26/11)**: sécurité et accélération de la CI.
- **Mandat de nuit (du 26/11 au soir au 27/11 avant 06h00)**: réalisé, état détaillé et vérifications dans
  [`docs/AUDIT-2026-11-27.md`](AUDIT-2026-11-27.md). L'autorisation de commiter et fusionner valait pour ce mandat
  seulement: **la redemander désormais**.

## En attente d'une décision de l'utilisateur

Détail dans le backlog: hébergement (environnement permanent, état Terraform distant, sauvegardes); protection de
l'API; protection de `main`; Quality Gates Sonar bloquants; séparation de la base (détails); canal de notification;
format de téléphone; ordre ou parallélisme du job `lint`; sort de `.gitlab-ci.yml`.

## Où on en est

- Fin de la nuit du 26 au 27/11: PR #43 à #56 ([`docs/AUDIT-2026-11-27.md`](AUDIT-2026-11-27.md)). Dernière release
  au 27/11 au soir: `v0.2.4` (promue). Les trois Quality Gates Sonar ne sont pas bloquants.
- **Une fusion sur `main` contenant `feat`, `fix`, `perf`, `build` ou un changement cassant publie des images
  candidates, puis une pré-version après le staging.**
- Historique détaillé (mesures, incidents, branches supprimées): [`docs/HISTORIQUE-SESSIONS.md`](HISTORIQUE-SESSIONS.md),
  à ne consulter qu'au besoin.

## À savoir pour travailler

- Quand deux sessions utilisent le même dossier, travailler dans un worktree (`git worktree add`).
- Dépôt fork: sur ce poste, le dépôt par défaut de `gh` est celui d'`origin` (`gh repo set-default --view`). Sur un
  poste sans ce réglage, passer `--repo` à `gh pr create` pour ne pas viser le dépôt d'OpenClassrooms.
- Aucun fichier de licence trouvé, ni ici ni dans le dépôt d'origine: le dépôt est public, pas open source.
- `docs/inputs/` (sujet, mails, modèles) reste dans le dépôt (décision du 26/11).

## Prochaine étape (proposée, non décidée)

- Séparation de la base (besoin donné le 27/11): plan en 5 PR dans le backlog, à commencer après accord de
  l'utilisateur; une réponse attendue (données à conserver).
1. Prendre les décisions ci-dessus, en commençant par la sécurité (API, `main`).
2. Corriger les 7 vulnérabilités moyennes des images (backlog).
3. Accélération: détection Gradle du scan `sonar-back` (31 s), cache des couches Docker.

Seuils de couverture: 80 % pour le front et pour le back, tout le code et code nouveau, **bloquants**. Sonar ne
compte pas les templates HTML.

## Questions ouvertes

- GitHub au lieu de GitLab (le mail 2 demande un lien GitLab public): à confirmer avec le mentor (risque R2).
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
