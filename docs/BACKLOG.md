# Backlog

## À faire

- [ ] ci: ajouter le cache npm et Gradle (`cache:` de `setup-node` / `setup-java`)
  - Pré-requis: mesurer les durées de run sans cache (`gh run view`), puis avec cache.
  - Mesure sans cache (premier run, 18/11/2026): test-back ~48 s, test-front ~59 s, build-front ~45 s,
    build-back ~45 s, soit environ 2 min au total.
  - Justification: gain non démontré, retiré du premier workflow.

- [ ] docker: figer les versions des images, jamais `latest`, et les référencer par digest
  - Reste à traiter (actions GitHub et runner déjà faits, cf. « Fait »): les images du `Dockerfile`
    (`node` et `gradle:jdk17` sans version précise, `alpine:3.19`): version fixe plus digest
    (`image:version@sha256:...`), avec la version en commentaire comme pour les actions.
  - Ajouter l'écosystème `docker` à `.github/dependabot.yml` une fois les images épinglées.
  - À coordonner avec la mise à jour des images (Alpine, Java 21) pour ne pas épingler deux fois.

### Résoudre les CVE (en particulier les critiques) en mettant à jour les briques obsolètes

Constat sur l'état initial (tag `v0.0.1`, analyse du 18/11/2026, dates de fin de support d'après endoflife.date):
`npm install` du front signale 90 vulnérabilités (7 low, 27 moderate, 51 high, 5 critical),
cf. `docs/logbook/0.0.1-initial-state/front.log`. Les 8 vulnérabilités des dépendances de production
viennent d'Angular et ne se corrigent qu'avec Angular 22. Les 5 critiques sont transitives
(`piscina`, `tar`, `proxy-addr`, `shell-quote`, `websocket-driver`): `piscina` et `tar` disparaissent avec
`@angular-devkit/build-angular` et `@angular/cli` récents, les trois autres se corrigent sans montée majeure.

Critère de choix des versions: version LTS quand elle existe, et fin de support postérieure à 05/2027.

| Brique | Actuelle (fin de support) | Cible (fin de support) |
|---|---|---|
| Angular | 17.3 (15/05/2025, dépassée) | 22 (30/06/2028) |
| Spring Boot | 3.2.5 (31/12/2024, dépassée) | 4.1.x (31/07/2027) |
| Alpine | 3.19 (01/11/2025, dépassée) | 3.24 (01/06/2028) |
| Node.js | 20 (30/04/2026, dépassée) | 24 LTS (30/04/2028) |
| Java | 17 pour compiler, 21 dans l'image | 21 LTS (31/12/2029) partout |
| Gradle | 8.7 | 9.x, dernière mineure (pas de LTS ni de date de support, cf. ci-dessous) |

Gradle n'a pas de LTS (vérifié sur la politique officielle, docs.gradle.org, feature_lifecycle, et sur
endoflife.date). Seule la dernière mineure de la dernière majeure est pleinement supportée (9.9.1 au
18/11/2026). La majeure précédente (8.14.x) ne reçoit plus que les correctifs critiques et de sécurité,
jusqu'à la sortie de la majeure suivante, sans date publiée. Le critère « fin de support après 05/2027 »
ne peut donc pas être garanti pour Gradle: on vise la dernière mineure de la 9.x et on met à jour le
wrapper (`./gradlew wrapper --gradle-version <x>`) à chaque nouvelle mineure.

Les cibles Spring Boot 4.1 et Angular 22 dépassent 05/2027 de peu pour Spring Boot (07/2027): réévaluer
la cible au moment de la migration si une version plus récente est sortie.

- [ ] front: migrer Angular 17 → 22
  - Une majeure à la fois avec `ng update` (18, 19, 20, 21, 22), tests et build verts à chaque étape.
  - TypeScript, zone.js, rxjs et outils de test (karma, jasmine) suivent les versions exigées par Angular.
  - Vérifier la compatibilité d'Angular 22 avec Node 24 (matrice de compatibilité officielle).
  - Résultat attendu: `npm audit` sans critique et sans vulnérabilité sur les dépendances de production.
- [ ] back: migrer Spring Boot 3.2.5 → 4.1.x
  - Passer par les étapes documentées (3.5, puis 4.0, puis 4.1), tests verts à chaque étape.
  - Mettre à jour Gradle (dernière mineure de la 9.x, ou au minimum la version exigée par Spring Boot,
    à confirmer dans ses notes de version) et les plugins.
  - Vérifier l'état de maintenance de `ro.polak:spring-boot-data-fixtures:0.2.0`, remplacer si abandonnée.
  - Passer `sourceCompatibility` à Java 21.
- [ ] back: verrouiller les dépendances Gradle (`gradle.lockfile`)
  - Constat: Sonar `S8569` sur `back/build.gradle`. Sans fichier de verrouillage, les versions résolues
    peuvent changer d'un build à l'autre (plugins, dépendances transitives), ce qui rend la CI et les images
    non reproductibles. C'est l'équivalent Gradle du `package-lock.json` côté front.
  - À faire APRÈS la migration Spring Boot (tâche ci-dessus): le fichier fige les versions, le générer avant
    obligerait à le régénérer à chaque étape de la migration.
  - Activer le verrouillage de toutes les configurations dans `build.gradle`
    (`dependencyLocking { lockAllConfigurations() }`), générer le fichier avec
    `./gradlew dependencies --write-locks`, et le commiter.
  - Mise à jour ensuite: régénérer le fichier avec la même commande à chaque changement de version voulu.
    Par défaut Gradle échoue si les versions résolues diffèrent du fichier, mais pas si le fichier est
    absent: ajouter `lockMode = LockMode.STRICT` pour que ce second cas échoue aussi.
  - Vérifier que les tests et le build restent verts en CI, et que `S8569` disparaît de Sonar.
- [ ] docker: mettre à jour les images
  - Alpine 3.19 → 3.24 (vérifier la disponibilité de `caddy`, `openjdk21-jre-headless`, `supervisor`).
  - Aligner Java sur 21 entre compilation (`gradle:jdk17` → image JDK 21) et exécution.
  - Remplacer `node` et `gradle:*` en `latest` par des versions fixes (cf. tâche des versions figées).
  - Appliquer au `Dockerfile` le correctif déjà fait dans le workflow (règles Sonar `S6505` et `S8543`,
    lignes 7 et 8): `npm ci --ignore-scripts` puis `npm run build -- --optimization` à la place de
    `npx @angular/cli build --optimization`. Validé en CI, à valider aussi par un build d'image.
  - Les images finales tournent en `root` par défaut (Sonar `S6471`): ajouter un utilisateur non privilégié
    si l'application le permet (ports 80 et 443 pour Caddy: à vérifier).
- [ ] docker: étudier le remplacement de Caddy par nginx (à l'étude, décision non prise)
  - Motivation: nginx est plus standard et mieux documenté que Caddy. Ce n'est pas un argument de sécurité:
    avec un `USER` explicite, un port élevé et les bons droits, les deux donnent un conteneur non-root équivalent.
  - Rôle actuel de Caddy: serveur de fichiers statiques du front, avec compression gzip et repli sur
    `/index.html` pour les routes Angular (`misc/docker/Caddyfile`). Il ne fait pas de proxy vers le back.
  - À remplacer si la décision est prise: `apk add caddy` et `CMD` du stage `front` (`Dockerfile`),
    `COPY misc/docker/Caddyfile`, et la commande `caddy run` de `misc/docker/supervisor.ini` (image `standalone`).
  - À écrire: un `misc/docker/nginx.conf` équivalent (`root /app/front`, `gzip on`,
    `try_files $uri /index.html`), lancé avec `nginx -g "daemon off;"`.
  - Deux options à comparer:
    - A (défaut): `apk add nginx` sur Alpine, plus configuration non-root dans `nginx.conf`
      (`listen 8080`, `pid /tmp/nginx.pid`, `*_temp_path` dans `/tmp`) et `USER nginx`.
      Garde la structure du `Dockerfile`, notamment le stage `standalone`.
    - B: image `nginx-unprivileged` (non-root, port 8080, PID et temporaires dans `/tmp`, maintenue par l'équipe
      nginx; registre `nginx/nginx-unprivileged` pour les versions récentes, `nginxinc/...` pour les anciennes,
      à vérifier). Risque: le stage `standalone` copie tout le système de fichiers de `front` et `back`
      (`COPY --from=front / /`), ce qui se complique si `front` change d'image de base.
      Pertinent si les images sont restructurées.
  - Dans les deux cas, épingler la version et le digest de l'image (cf. tâche des versions figées).
  - Points à vérifier: le rechargement d'une route profonde renvoie bien `index.html`, la compression est
    active, et les ports exposés (80 et 443 dans le `Dockerfile`) correspondent à ce que nginx écoute.
  - Le non-root (`S6471`) est un chantier distinct: Sonar ne vise que le stage `standalone` (ligne 44), qui
    lance `supervisord` en root pour le serveur web et Java. Il faut un `USER`, un `supervisord` non-root
    (son socket `/var/run/supervisor.sock` n'est pas accessible à un autre utilisateur) et le back sous le même
    utilisateur, quel que soit le serveur choisi.
  - À faire avec la mise à jour d'Alpine, pour n'installer qu'une fois le paquet nginx de la version cible.
- [ ] ci: aligner le workflow sur les nouvelles versions
  - `node-version: 20` → 24, `java-version: 17` → 21, dans `.github/workflows/ci.yml`.
  - À faire en même temps que les migrations front et back correspondantes, pas avant.
- [ ] sonar: traiter les issues de l'état initial (35: 20 bugs, 9 code smells, 6 vulnérabilités)
  - Source: `docs/quality/0.0.1-initial-state/sonar-main-issues.json` (cliché du 18/11/2026).
  - Vulnérabilités du `Dockerfile` (`S6505`, `S8543`, `S6471`): traitées dans la tâche « docker ».
  - `back/build.gradle` (`S8569`): traité dans la tâche « back: verrouiller les dépendances Gradle ».
  - `front/src/index.html` (`S5725`): feuille de style Bulma chargée depuis un CDN sans contrôle d'intégrité.
    Ajouter `integrity` et `crossorigin="anonymous"` (hash SRI), ou mieux, installer Bulma via npm pour
    l'embarquer dans le bundle et supprimer la dépendance au CDN.
  - Bugs du front (20): promesses non gérées (`typescript:S9383`, 12), champs de formulaire sans label
    (`Web:InputWithoutLabelCheck`, 7), tableau sans en-têtes `<th>` (`Web:S5256`, 1).
  - Code smells (9): labels de formulaire (`Web:S6853`, 6), opération asynchrone dans un constructeur
    (`typescript:S7059`, 1), `Number.parseInt` à préférer à `parseInt` (`typescript:S7773`, 2).
  - À faire de préférence après la migration d'Angular, pour ne pas corriger deux fois du code touché par `ng update`.
- [ ] ci: améliorer la précision de l'analyse Java de Sonar (`sonar.java.libraries`)
  - Constat: le scan signale `Missing 'sonar.java.libraries'` et des types non résolus, car le scanner générique
    (choisi pour garder un seul projet Sonar) ne connaît pas le classpath Gradle, contrairement au plugin
    `org.sonarqube`.
  - Piste: une tâche Gradle qui écrit le classpath de compilation, passé au scan via `-Dsonar.java.libraries=...`.
  - À faire après la migration de Spring Boot (le classpath change), et à comparer au nombre d'issues Java actuel.
- [ ] sécurité: auditer le back et les images, puis scanner dans la CI
  - Back (Gradle) et images Docker n'ont pas encore été analysés.
  - Ajouter un scan de vulnérabilités dans la CI une fois les mises à jour faites, pour ne pas les réintroduire.

## Fait

- [x] ci: workflow GitHub Actions équivalent à `.gitlab-ci.yml` (PR #1)
- [x] ci: vulnérabilités Sonar du workflow corrigées (`S6505`, `S8543`): Angular CLI lancé depuis le lockfile
  (`npm test`, `npm run build`) au lieu de `npx @angular/cli`, et `npm ci --ignore-scripts`
- [x] ci: actions GitHub épinglées par SHA avec la version en commentaire (`checkout` v7.0.1, `setup-node` v7.1.0,
  `setup-java` v6.3.0, ce qui supprime les avertissements Node 20), runner `ubuntu-26.04` à la place de
  `ubuntu-latest`, et Dependabot pour les actions GitHub (`.github/dependabot.yml`)
- [x] ci: analyse SonarQube lancée depuis la CI (`sonarqube-scan-action` v8.5.0, un seul projet) à la place de
  l'analyse automatique, avec la couverture de tests (JaCoCo pour le back, lcov pour le front). Le job `sonar` ne
  tourne que sur les PR (hors forks) et sur `main`; organisation et clé du projet déduites du contexte GitHub
- [x] qualité: cliché SonarQube de l'état initial dans `docs/quality/0.0.1-initial-state/`
  (35 issues, 262 risques de dépendances) et script `scripts/sonar-export.sh`
- [x] état initial: logbooks dans `docs/logbook/0.0.1-initial-state/` et tag `v0.0.1`
