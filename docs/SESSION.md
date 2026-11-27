# État de session

Fichier de passage de relais entre sessions (Claude CLI, Claude dans VS Code). À mettre à jour à la fin de chaque
lot de travail. Les règles de travail sont dans `CLAUDE.md`, les tâches dans `docs/BACKLOG.md`.

**Dernière mise à jour: 27/11/2026**

## Dernier lot: staging avant la release (branche `ci/staging-release`)

Demandé le 27/11: trois images dans un job (`standalone` réutilise les étapes), démarrage de `standalone` testé, mêmes
empreintes en staging et en production, staging identique à la production, release seulement après le staging,
production par changement de statut de la release. Ajout: `paths-ignore` (pas de CI pour `**.md`, `docs/`,
`learning/`). Commit, PR et fusion en rebase autorisés par l'utilisateur pour ce lot.
À savoir avant la fusion: `candidate`, `release` et `promote.yml` ne s'exécutent que sur `main`; la fusion de commits
`build`, `feat`, `fix` ou `perf` publie une pré-version. Fonctionnement: `docs/DEPLOIEMENT.md`, §6.

**Mis de côté: branche `ci/local-scripts` (locale, non poussée, non fusionnée).** Scripts de lancement et Helm,
`ci_local.sh`, ShellCheck dans la CI, `workflow_dispatch` et section « Scripts » du README. L'installation Helm sur
minikube par ces scripts n'a pas abouti et son nettoyage a été interrompu: vérifier l'espace `microcrm-dev`, puis
valider avant fusion. L'option `MINIKUBE_PROFILE` envisagée n'a pas été écrite. L'ancienne branche locale
`ci/staging-promotion` mélange les deux travaux: ne pas la pousser.

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

- `main` à la fin de la nuit du 26 au 27/11: pipeline CI/CD complet du schéma (PR #43 à #56), dernière version
  publiée `v0.2.2`, les trois Quality Gates Sonar OK (non bloquants). Bilan, preuves et réserves:
  [`docs/AUDIT-2026-11-27.md`](AUDIT-2026-11-27.md).
- **Une fusion sur `main` contenant `feat`, `fix`, `perf`, `build` ou un changement cassant publie une version et
  des images publiques.** (Avec le lot en cours: des images candidates, puis une pré-version après le staging.)
- Historique détaillé (mesures, incidents, branches supprimées): [`docs/HISTORIQUE-SESSIONS.md`](HISTORIQUE-SESSIONS.md),
  à ne consulter qu'au besoin.

## À savoir pour travailler

- Quand deux sessions utilisent le même dossier, travailler dans un worktree (`git worktree add`).
- Dépôt fork: sur ce poste, le dépôt par défaut de `gh` est celui d'`origin` (`gh repo set-default --view`). Sur un
  poste sans ce réglage, passer `--repo` à `gh pr create` pour ne pas viser le dépôt d'OpenClassrooms.
- Aucun fichier de licence trouvé, ni ici ni dans le dépôt d'origine: le dépôt est public, pas open source.
- `docs/inputs/` (sujet, mails, modèles) reste dans le dépôt (décision du 26/11).

## Prochaine étape (proposée, non décidée)

0. Valider la branche `ci/local-scripts`, puis la proposer en PR.
- Séparation de la base (besoin donné le 27/11): plan en 5 PR dans le backlog, après la fusion du lot staging;
  deux réponses attendues (`standalone`, données à conserver).
1. Prendre les décisions ci-dessus, en commençant par la sécurité (API, `main`).
2. Corriger les 7 vulnérabilités moyennes des images (backlog).
3. Accélération: détection Gradle du scan `sonar-back` (31 s), cache des couches Docker.

Seuils de couverture: 80 % pour le front et pour le back, tout le code et code nouveau, **bloquants**. Sonar ne
compte pas les templates HTML.

## Questions ouvertes

- GitHub au lieu de GitLab (le mail 2 demande un lien GitLab public): à confirmer avec le mentor (risque R2).
- Règle `ignore` de Dependabot pour Docker: non confirmée (il n'a pas encore ouvert de PR).
