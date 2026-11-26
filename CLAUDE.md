# Instructions pour Claude (CLI et VS Code)

Projet: monorepo `front` (Angular), `back` (Spring Boot, Gradle), `Dockerfile` (Caddy + supervisor). Travail de
modernisation et de durcissement du dépôt (CI GitHub Actions, Sonar, versions, sécurité).

**Au début d'une session, lire `docs/SESSION.md` (état courant, prochaine étape) puis `docs/BACKLOG.md`.
À la fin d'un lot de travail, mettre à jour `docs/SESSION.md`** (l'utilisateur alterne entre plusieurs sessions
et outils, ce fichier est la seule mémoire commune).

## Règles de travail (consignes de l'utilisateur)

- Langue: français, avec l'utilisateur et dans la documentation.
- Toujours travailler sur une branche de dev (`front/…`, `back/…`, `ci/…`, `docs/…`), jamais sur `main`.
- Commits en conventional commits, petits et découpés par sujet. Justifier chaque choix technique (commentaire
  dans le fichier ou message de commit).
- **Demander avant de commiter ou pousser**, sauf si l'utilisateur l'a dit explicitement. Sa formule habituelle:
  « commit, push, PR et fusion en rebase ».
- Ouvrir la PR seulement quand la CI de la branche est verte. Fusion en **rebase** (`gh pr merge --rebase --delete-branch`).
- Versions: LTS avec support au-delà de 05/2027. Images et actions épinglées par SHA/digest, version en commentaire.
- Ne pas écrire l'identifiant GitHub de l'utilisateur en dur dans les scripts.
- Pas de `git reset --hard` ni de push forcé: créer une nouvelle branche à la place.
- Avant de déclarer un correctif terminé: test qui échoue sans lui, build et tests verts.

## Commandes

```bash
# Back (http://localhost:8080) puis front (http://localhost:4200); arrêt: Ctrl+C
cd back && ./gradlew bootRun
cd front && npm ci --ignore-scripts && npm start

# Tests
cd back && ./gradlew clean build
cd front && npx ng test --watch=false --coverage      # Vitest avec jsdom, sans navigateur
cd front && npm run build -- --optimization     # budget de bundle: avertissement à 850 kB (actuel ~814 kB)
```

## Pièges connus

- Vitest laisse les espions (`vi.spyOn`) en place d'un test à l'autre: `front/src/test-setup.ts` les restaure
  après chaque test. Ne pas le retirer. Vitest n'a pas de LTS: suivre la dernière mineure, comme pour Gradle.
- `~/.npmrc` de l'utilisateur contient `allow-scripts=…`: `ng update` échoue (EALLOWSCRIPTS). Le lancer avec
  `NPM_CONFIG_USERCONFIG=<fichier vide>`.
- Dépendances Gradle verrouillées (STRICT): après un changement dans `back/build.gradle`, lancer
  `./gradlew dependencies --write-locks` et commiter `back/gradle.lockfile`.
- Spring Data REST: `PUT` sur une association remplace la liste, `POST` (text/uri-list) ajoute. Le côté propriétaire
  de la relation est `Organization.persons`.
- Sonar: projet `denoyela-4913_dev-project-06-orion`, job `sonar` de la CI seulement sur PR et `main`.
  `scripts/sonar-export.sh` exporte l'état (`docs/quality/`).
- Tuer un serveur par port (`kill $(lsof -ti :8080)`), jamais par `pkill -f`.
