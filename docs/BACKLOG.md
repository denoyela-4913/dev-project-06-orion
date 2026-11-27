# Backlog

## À faire

### Priorité (donnée par l'utilisateur le 26/11): sécurité et accélération de la CI

- [ ] ci: éviter que le scan Sonar télécharge la distribution Gradle (étape « Detecting build system
  information », 27 à 38 s mesurées sur les runs à un seul scan après la PR #19, contre 8 s avant). À remesurer
  avec les trois scans parallèles (PR #33) avant de corriger
- [ ] ci: cache npm (cf. l'entrée plus bas; gain attendu faible: `npm ci` prend 4 à 8 s par job)
- [ ] sécurité (en attente de décision: réglage du dépôt GitHub, hors des fichiers versionnés): protéger `main` en
  exigeant les jobs de CI. Aujourd'hui `main` n'a ni protection ni règle: une PR en échec reste fusionnable
- [ ] sécurité: le journal de l'action de scan Sonar signale que la sous-clé de signature du scanner est révoquée
  (motif: remplacement), la vérification réussissant quand même. Non étudié

### Pipeline CI/CD cible (schéma `docs/livrables/schema_pipeline_ci_cd.png`), mandat du 26/11 au soir

Objectif: toutes les cases du schéma « faites », ou une entrée « en attente de décision ». Une PR par lot.

- [ ] ci: release sur `main` (version SemVer et tag, images publiées sur GHCR, notes de release)
- [ ] cd: déploiement de démonstration, test de santé HTTP, notification du résultat
- [ ] cd: retour arrière automatique (`helm rollback`) et sauvegarde des données
- [ ] cd: livraison manuelle de secours
- [ ] tests: compléter les tests unitaires, fonctionnels et de bout en bout
- [ ] docs: documentation CI/CD et déploiement à jour, schéma à jour
- [ ] docs: fiches et flashcards sur le projet, dont les processus CI et CD (`learning/`)
- [ ] docs: audit et état des lieux de la nuit (à écrire vers 04h00 le 27/11, tenu à jour jusqu'à la fin)
- [ ] docs: `README.md` périmé (Spring Boot 3, Angular 17, OpenJDK 17, `npx @angular/cli serve`, GitLab CI)
- [ ] ci (en attente de décision: supprimer ou porter): `.gitlab-ci.yml` d'origine n'est plus fonctionnel pour
  les tests du front (options de Karma, cf. `docs/KARMA.md`)

### Autres tâches

- [ ] cd (en attente de décision: hébergement): créer un environnement permanent (cluster, domaine, certificat,
  stockage). Terraform devrait alors aussi créer le cluster, avec un état distant, chiffré et verrouillé à la place
  de l'état local
- [ ] cd: sauvegardes planifiées et stockées hors de la machine qui les lance (aujourd'hui: à la demande et avant
  chaque mise à jour, en local); procédure de rétention. Lié au choix de l'hébergement
- [ ] ci: suivre les mises à jour des images de Trivy et de Playwright (références par digest dans
  `scripts/trivy.sh` et `scripts/e2e.sh`, que Dependabot ne voit pas), ainsi que celle de hadolint (`ci.yml`) et
  les versions de kind, Helm et Terraform
- [ ] données (en attente de décision: base de données de production): HSQLDB interne au back limite à une instance
  et à une coupure par mise à jour; PostgreSQL (et un outil de migration à la place de `ddl-auto=update`) à décider
- [ ] ci: mettre en cache les couches Docker (le job `images` reconstruit tout à chaque run, tests du back compris)
- [ ] back: `spring.jpa.open-in-view` est actif par défaut (avertissement au démarrage); à désactiver après
  vérification des accès paresseux de Spring Data REST
- [ ] front: passer les composants en `ChangeDetectionStrategy.OnPush` (règle ESLint
  `prefer-on-push-component-change-detection` désactivée): les composants changent leur état après des promesses
  et comptent sur la détection par défaut; à faire avec des signaux, composant par composant
- [ ] ci (en attente de décision: vitesse ou ordre du schéma): le job `lint` précède les tests, comme sur le
  schéma; chaque run réussi attend sa durée. Le lancer en parallèle des tests (les builds attendant les deux)
  raccourcirait le chemin
- [ ] ci: ajouter le cache npm (`cache:` de `setup-node`; le cache Gradle est fait, cf. « Fait »)
  - Pré-requis: mesurer les durées de run sans cache (`gh run view`), puis avec cache.
  - Mesure sans cache (premier run, 18/11/2026): test-back ~48 s, test-front ~59 s, build-front ~45 s,
    build-back ~45 s, soit environ 2 min au total.
  - Justification: gain non démontré, retiré du premier workflow.

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

- [ ] back: vérifier la maintenance de `ro.polak:spring-boot-data-fixtures:0.2.0`
  - Fonctionne avec Spring Boot 4.1.2 (jeu de données de démonstration chargé), mais l'état de maintenance de
    la bibliothèque n'a pas été vérifié: la remplacer si elle est abandonnée.
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
  - Comportement actuel de Caddy (vérifié par un build d'image): sert en HTTPS sur le port 443 avec un certificat
    qu'il génère lui-même (autorité interne), et redirige le port 80 vers HTTPS (308). nginx devra reproduire ce
    comportement ou le simplifier (HTTP seul): à décider.
  - Points à vérifier: le rechargement d'une route profonde renvoie bien `index.html` et la compression est
    active (les deux fonctionnent aujourd'hui avec Caddy).
  - Le non-root (`S6471`) est déjà fait avec Caddy (cf. « Fait »): si nginx le remplace, reprendre l'utilisateur
    `app` (uid 10001) et le `supervisord` non-root, et décider des ports: Caddy garde 80 et 443 grâce à
    `setcap cap_net_bind_service`, nginx pourrait passer sur des ports élevés (le mappage `-p 80:<port>` du
    README suffit à garder les mêmes URL).
  - À faire avec la mise à jour d'Alpine, pour n'installer qu'une fois le paquet nginx de la version cible.
- [ ] ci: améliorer la précision de l'analyse Java de Sonar (`sonar.java.libraries`)
  - Constat: le scan signale `Missing 'sonar.java.libraries'` et des types non résolus, car le scanner générique
    (choisi pour garder un seul projet Sonar) ne connaît pas le classpath Gradle, contrairement au plugin
    `org.sonarqube`.
  - Piste: une tâche Gradle qui écrit le classpath de compilation, passé au scan via `-Dsonar.java.libraries=...`.
  - À faire après la migration de Spring Boot (le classpath change), et à comparer au nombre d'issues Java actuel.
- [ ] front: corriger les défauts d'affichage et de navigation relevés pendant le lot des promesses (26/11)
  - Une correction par commit, avec un test qui échoue d'abord. Aucun n'est signalé par les issues Sonar traitées
    dans les trois lots d'issues Sonar du front (cf. « Fait »). Priorité non décidée.
  - Vu à l'écran (front lancé sans le back):
    - tableau de bord: après un échec de chargement, « No person yet » et « No organization yet » s'affichent sous
      les messages d'erreur, comme si les listes étaient vides;
    - page d'une organisation: après un échec de chargement, le titre est `Organization ""`. La page d'une personne
      a le même modèle de titre (non vu à l'écran).
  - Vu à la lecture du code, non reproduit dans le navigateur:
    - tableau de bord: le lien « Create one » des organisations vise `organization/new` (singulier,
      `main-dashboard.component.html`). Aucune route ne correspond: la route `**` renvoie à l'accueil;
    - page d'une personne, bouton « + »: **corrigé** avec le lot lint (26/11);
    - page d'une personne: le message « Phone must be a valid phone number. » attend une erreur `tel` qu'aucun
      validateur ne produit.
- [ ] sécurité: CORS n'est pas un contrôle d'accès, protéger l'API (portée et solution non décidées)
  - Constat (26/11): aucune dépendance ni configuration de sécurité dans le back. Spring Data REST expose les
    personnes et les organisations (`PersonRepository`, `OrganizationRepository`), lecture et écriture, sur le port
    8080, que le README publie avec `docker run -p 8080:8080`. Les données comprennent des informations
    personnelles (dont l'email).
  - La restriction des origines (cf. « Fait ») ne concerne que les navigateurs: elle empêche une page d'une autre
    origine de lire les réponses de l'API ou d'envoyer les requêtes soumises au preflight. `curl`, un script ou un
    autre serveur ne sont pas concernés.
  - À décider: besoin réel pour ce projet, puis solution (authentification avec Spring Security, ou accès à l'API
    limité au niveau réseau ou proxy). Une authentification demande aussi des changements dans le front.
  - Une correction devra avoir des tests qui échouent d'abord (requête sans identification refusée).

## Fait

- [x] cd: Terraform, découpé en modules et en environnements
  - `deploy/terraform/`: modules `platform` (espace de noms « restricted », quota, valeurs par défaut; testé avec un
    fournisseur simulé) et `microcrm` (release Helm), un dossier et un état par environnement, fournisseurs
    verrouillés. CI (`infra-check`): format, validation des trois environnements, tests. `apply` vérifié sur minikube.
    Aucune ressource payante n'est créée: Terraform suppose un cluster existant.
- [x] cd: charts Helm avec des valeurs par environnement (dev, staging, production)
  - Chart `deploy/helm/microcrm` avec `values-dev`, `values-staging` et `values-production`; pods sans root,
    lecture seule, compatibles « restricted »; back limité à une instance (le chart refuse davantage). Vérifié en
    CI (`infra-check`) et sur minikube. Défaut trouvé par le test de santé et corrigé: derrière le proxy, une
    écriture de la même origine était refusée (403) dès que l'adresse différait de celle configurée.
- [x] sécurité: auditer les dépendances du back et les images Docker, puis scanner dans la CI (cf. l'entrée
  « auditer le back et les images » plus bas)
  - Audit du 26/11 au soir: 0 vulnérabilité (verrous npm et Gradle, trois images), 0 secret, 0 erreur de
    configuration du Dockerfile. Détail: `docs/SECURITE.md`.
- [x] ci/sécurité: scan Trivy (images, Dockerfile, dépendances), avec un scan hebdomadaire
  - Job `scan` (dépôt et trois images, bloquant sur critique ou haute avec correctif), rescan le lundi (workflow
    « Scan de sécurité »), `scripts/trivy.sh`. Image officielle 0.76.2 par digest, sans action Trivy (compromission
    de mars 2026). Le script échoue bien sur un verrou de test vulnérable.
- [x] ci: construction des images Docker dans la CI
  - Jobs `images` (front, back, standalone, transmises par artefact) et `compose-test` (les trois environnements).
- [x] docker: images prêtes au déploiement (sonde de santé, adresse de l'API réglable) et Docker Compose
  (dev, staging, production)
  - Sondes de santé (Actuator, seul `health` exposé; `/healthz` côté front), adresse de l'API réglable au
    démarrage (`/config.js`), proxy `/api` dans Caddy, données en fichier possible (`/data`). Compose: socle et un
    fichier par environnement (`deploy/compose/`, `scripts/compose.sh`), test de déploiement `scripts/smoke_test.sh`.
    Les trois environnements vérifiés en local (données conservées après recréation en staging, 403 sur une origine
    étrangère, écriture en HTTPS en production). Défaut trouvé par ce test et corrigé: les volumes de Caddy
    appartenaient à root. Documentation: `docs/DEPLOIEMENT.md`.
- [x] ci: stage lint (ESLint pour le front, hadolint pour les Dockerfile)
  - Job `lint` avant les tests: hadolint (image 2.15.1 épinglée par digest) et ESLint (10.15, angular-eslint 22.8,
    typescript-eslint 8.73, `no-floating-promises`), zéro avertissement toléré. 23 écarts ESLint et 10 remarques
    hadolint corrigés: `inject()`, types HAL, `USER` numérique, paquets Alpine épinglés à la mineure.
  - Défaut corrigé au passage: sur la page d'une personne, le clic était sur le texte du bouton « + » et non sur le
    bouton (clavier sans effet, bouton sans `type`). Test qui échoue sans le correctif.
- [x] back: corriger les 2 code smells `java:S6813` (injection par champ, `InitialDataFixture.java` lignes 14 et 17)
  - Fait le 26/11: injection par constructeur dans `InitialDataFixture`.
- [x] ci/back: ajouter Checkstyle et SpotBugs au build Gradle (décision du 26/11)
  - Checkstyle 14.4.0 (règles ciblées, `back/config/checkstyle/`) et SpotBugs (plugin 6.5.13), bloquants avec zéro
    écart, lancés par `./gradlew build`. Premiers résultats: 26 écarts Checkstyle (tabulations, import inutilisé, fin
    de fichier, noms de test `whenX_thenY`, convention autorisée dans la règle) et 8 `EI_EXPOSE_REP` SpotBugs:
    dates et tableau CORS corrigés par des copies (test qui échoue sans elles), liste JPA et bean injecté exclus avec
    justification (`back/config/spotbugs/exclude.xml`). Choix « bloquant » fait pendant le mandat de nuit,
    réversible (`ignoreFailures`).
- [x] ci: seuils de couverture en mode bloquant, par une PR dédiée (26/11)
  - `COVERAGE_BLOCKING: "true"` dans le job `coverage`. Les 4 taux sont bloquants: tout le code et code nouveau, pour
    le front et le back. Au passage: front 97,5 % (242/248), back 93,9 % (77/82).
  - Vérifié en local sur de vrais rapports avec `--blocking`: code de sortie 0 au seuil de 80 %, 1 avec
    `--threshold 99`.
  - Commentaire périmé de `ci.yml` corrigé (il parlait encore d'un seul gate Sonar commun aux deux parties).
  - Les Quality Gates Sonar (un par projet) ne sont pas concernés (`sonar.qualitygate.wait`, protection de `main`:
    non décidés). `main` n'étant pas protégée, un job en échec n'empêche pas à lui seul une fusion.
- [x] ci: nom des projets Sonar et export d'un jalon en une commande (26/11)
  - `sonar.projectName` dans les trois `sonar-project.properties`: sans lui, le scanner reprenait le nom du projet
    Gradle et npm, et le front et le back s'affichaient tous deux « microcrm ».
  - `scripts/sonar-export-release.sh <tag>`: exporte les trois projets sous `docs/quality/<tag>/<partie>/`. Il
    refuse d'écrire si la dernière analyse de `main` ne porte pas sur le commit du tag (Sonar ne garde que l'état
    courant): créer le tag, attendre la CI de `main`, puis lancer (`-f` pour forcer). Essayé avec un tag local
    temporaire sur `main`, avec `v0.0.2` (refus attendu) et avec `-f`.
- [x] ci: trois projets Sonar (`_front`, `_back`, `_infra`) et trois scans en parallèle (PR #33, fusionnée le 26/11)
  - Demande de l'utilisateur: un Quality Gate par partie. Un gate par projet Sonar: `infra` regroupe le Dockerfile, les
    workflows et les scripts (pas de couverture mesurée). Un `sonar-project.properties` par dossier de base (`front/`,
    `back/`, racine). Les chemins lcov du front n'ont plus besoin d'être réécrits. L'ancien projet
    `denoyela-4913_dev-project-06-orion` n'est plus analysé (conservé comme référence des clichés `docs/quality/`).
  - Mesuré (run 45880516355 sur `main`): run 131 s (181 s avec un seul scan, 127 s à `v0.0.2`); scans front 48 s, back
    62 s, infra 50 s (un seul scan: 104 s). Quality Gate de la PR: OK pour les trois projets.
  - `main` après la PR: front 993 lignes, 78,2 % de couverture, 0 issue; back 220 lignes, 93,9 %, 2 code smells; infra
    483 lignes (docker 32, py 124, shell 104, yaml 223), 0 issue. Le statut du gate sur la branche `main` n'est pas
    encore affiché par l'API (à revérifier après une seconde analyse).
  - Le jeton `SONAR_TOKEN` existant a suffi pour les trois projets.
  - `docs/` est exclu du projet infra (exports JSON, pas du code): `docs/quality/` n'est plus analysé (9 lignes avant).
- [x] ci: workflow GitHub Actions équivalent à `.gitlab-ci.yml` (PR #1)
- [x] ci: vulnérabilités Sonar du workflow corrigées (`S6505`, `S8543`): Angular CLI lancé depuis le lockfile
  (`npm test`, `npm run build`) au lieu de `npx @angular/cli`, et `npm ci --ignore-scripts`
- [x] ci: actions GitHub épinglées par SHA avec la version en commentaire (`checkout` v7.0.1, `setup-node` v7.1.0,
  `setup-java` v6.3.0, ce qui supprime les avertissements Node 20), runner `ubuntu-26.04` à la place de
  `ubuntu-latest`, et Dependabot pour les actions GitHub (`.github/dependabot.yml`)
- [x] ci: analyse SonarQube lancée depuis la CI (`sonarqube-scan-action` v8.5.0, un seul projet) à la place de
  l'analyse automatique, avec la couverture de tests (JaCoCo pour le back, lcov pour le front). Le job `sonar` ne
  tourne que sur les PR (hors forks) et sur `main`; organisation et clé du projet déduites du contexte GitHub
- [x] docker: images du `Dockerfile` épinglées par version et digest, version en commentaire (`node:24-slim`,
  `gradle:8.7-jdk17`, `alpine:3.19`), `npm ci --ignore-scripts` et `npm run build` à la place de `npx`
  (Sonar `S6505`, `S8543`), `as` → `AS`, et Dependabot pour Docker limité aux correctifs et digests.
  Vérifié par un build des 3 cibles et un test de démarrage (front HTTPS, repli SPA, gzip, API back)
- [x] qualité: cliché SonarQube de l'état initial dans `docs/quality/0.0.1-initial-state/`
  (35 issues, 262 risques de dépendances) et script `scripts/sonar-export.sh`
- [x] état initial: logbooks dans `docs/logbook/0.0.1-initial-state/` et tag `v0.0.1`
- [x] front: Bulma servi depuis npm au lieu du CDN (`S5725`). Version exacte `1.0.0` (la même, rendu identique,
  comparé à la version initiale). Bulma est compilé en modulaire (`front/src/bulma.scss`: seuls les modules
  utilisés, dont `themes` indispensable pour les variables CSS): 434 kB au lieu de 647 kB pour le CSS complet.
  Le budget Angular `maximumWarning` passe de 500 kB à 800 kB, car le CSS est maintenant dans le bundle
  (total initial en production: 745 kB). Pistes non faites: retirer le thème sombre (environ 100 kB, mais change le
  rendu en mode sombre), monter Bulma de version avec la migration Angular
- [x] versions: montée de toutes les briques obsolètes (branche `chore/upgrade-versions`, un commit par étape,
  tests et build verts à chaque étape)
  - Back: Spring Boot 3.2.5 → 3.5.16 → 4.0.9 → 4.1.2, Gradle 8.7 → 9.9.1, Java 17 → 21 (`sourceCompatibility`).
    Spring Boot 4 découpe ses modules de test: ajout de `spring-boot-starter-data-jpa-test` et nouveaux packages
    de `@DataJpaTest` et `TestEntityManager`. Vérifié sur le jar: API `/organizations` et `/persons`, CORS.
  - Front: Angular 17 → 18 → 19 → 20 → 21 → 22, TypeScript 5.4 → 6.0, zone.js 0.15, avec les migrations
    officielles de `ng update` à chaque étape. `npm audit`: 0 vulnérabilité (90 dans l'état initial, dont 5
    critiques). Budget Angular `maximumWarning` à 850 kB (804 kB en production).
  - Docker: Alpine 3.19 → 3.24, `gradle:9.9.1-jdk21`, `EXPOSE 8080` du stage `back`; les trois cibles se
    construisent et l'image `standalone` sert l'API et le front (HTTPS, gzip, repli SPA).
  - CI: Node 20 → 24 et Java 17 → 21 dans le workflow.
- [x] back: dépendances Gradle verrouillées (`S8569`): `dependencyLocking { lockAllConfigurations(); lockMode = STRICT }`
  dans `back/build.gradle` et `back/gradle.lockfile` versionné (134 lignes). Vérifié: le build passe, échoue si
  une version du fichier est modifiée, et le build Docker du back (`COPY ./back`) fonctionne. Mise à jour voulue
  d'une dépendance: `./gradlew dependencies --write-locks` puis commiter le fichier. Dependabot n'est pas
  activé pour Gradle: les mises à jour du back restent manuelles
- [x] docker: images exécutées en utilisateur non privilégié (`S6471`). Utilisateur `app` (uid 10001) dans les trois
  stages, `USER app`. Caddy garde les ports 80 et 443 (donc README et `docker run` inchangés) grâce à
  `setcap cap_net_bind_service=+ep` sur son binaire; le choix d'un port élevé aurait imposé de changer la
  redirection HTTP→HTTPS. `supervisord`: socket, journal et PID déplacés dans `/tmp` (non-root ne peut pas écrire
  dans `/var/run`). `skip_install_trust` dans le `Caddyfile`: sans root, Caddy ne peut pas installer son autorité
  interne dans le magasin système (erreur au démarrage, sans intérêt dans un conteneur). Vérifié sur les trois
  cibles: processus en uid 10001, ports 80/443, redirection 308, gzip, repli SPA, API sur 8080, journaux sans erreur.
  Limite: la capacité est ignorée avec `no-new-privileges` ou si `NET_BIND_SERVICE` est retirée du conteneur
- [x] front/back: bug fonctionnel, l'ajout d'une organisation à une personne ne mettait pas à jour la liste de l'organisation.
  La piste du backlog (promesse non attendue) était vraie mais incomplète. Reproduit sur l'API: (1) l'ajout utilisait
  `PUT` sur `/organizations/{id}/persons`, qui REMPLACE toute la liste (les autres personnes étaient retirées),
  il faut `POST`; (2) le retrait appelait `DELETE /persons/{id}/organizations/{org}`, qui répond 204 mais ne retire
  rien (`Person.organizations` est le côté inverse, `mappedBy`), il faut `DELETE /organizations/{org}/persons/{id}`;
  (3) `addSelectedOrganization` et `removeOrganization` n'attendaient pas la fin de l'appel avant `refresh()`;
  (4) vu à la validation visuelle: le tableau de la page personne parcourait `organizations` (toutes) au lieu de
  `person.organizations`, ce qui masquait les ajouts et retraits (corrigé, avec un test).
  Corrigé dans `organization.service.ts` et `person-details.component.ts`, avec 4 tests qui échouent sur l'ancien code
- [x] front/back: bug fonctionnel, le format du champ email n'était pas vérifié. Front: l'attribut `email` manquait sur
  l'`<input>` (le message d'erreur existait mais le validateur n'était pas actif). Back: `@Email` sur
  `Person.email` et `spring-boot-starter-validation`; le validateur est branché sur les événements `beforeCreate` et
  `beforeSave` de Spring Data REST, sinon l'API répondait 500 au lieu de 400 pour une valeur invalide. Un email vide
  reste accepté (champ facultatif). Tests: 3 côté front, 3 côté back (dont un test HTTP qui échoue sans la
  configuration). Test manuel de l'API: invalide 400 avec le détail, valide 201, vide 201
- [x] ci: le job `sonar` ne relance plus les tests, il récupère la couverture et les classes Java des jobs de tests
  par artefacts (PR #19). Il garde `npm ci` (types lus par l'analyse TypeScript) et n'utilise plus `setup-java`.
  Mêmes mesures Sonar sur PR qu'avant (191 lignes à couvrir, 93 non couvertes, couverture 48,2 %). Durée sur un
  run de PR: 201 s (run 45772862781) contre 246 s et 280 s avec l'ancien pipeline (runs 45719775318 et
  45771763791), `sonar` 91 s contre 132 s et 168 s. Un seul run mesuré, et la durée varie d'un run à l'autre.
  `build-back` (`./gradlew build`) relance les tests du back: conservé (décision du 26/11, cf. « ajouter Checkstyle
  et SpotBugs »). `./gradlew assemble` a été essayé en local, sans commit: plus court (environ 1 s contre 8 s,
  daemon déjà démarré), mais il ne lance pas `check`
- [x] ci: cache Gradle de `setup-java` dans `test-back` et `build-back` (PR #21). Fichiers de la clé listés (le choix
  par défaut ignore `gradle.lockfile`), cache du JDK désactivé. Commande Gradle sans cache sur 7 runs: 34 à 55 s
  (`test-back`) et 41 à 54 s (`build-back`); avec cache restauré dans `build-back`: 28 s et 30 s (runs 45806595627
  et 45807484510). Durée totale du premier run de `main` avec cache: 201 s (200 s au run précédent)
- [x] back: CORS limité aux origines du front (`java:S5122` ×3). Une seule configuration (plus de `@CrossOrigin`),
  origines dans `app.cors.allowed-origins` (`APP_CORS_ALLOWED_ORIGINS`), par défaut `http://localhost:4200` et
  `https://localhost`. `PUT` ajouté aux méthodes: le front l'utilise et il ne passait que grâce à `@CrossOrigin`.
  Tests `CorsTests`; vérifié sur le jar avec curl. Limite: CORS n'est pas un contrôle d'accès, l'API n'a pas
  d'authentification. Une autre adresse du front (ex. `http://127.0.0.1:4200`, autre port) doit être déclarée
- [x] front: promesses non gérées (`typescript:S9383`). Dans les trois composants, chaque échec affiche un message
  (`role="alert"`, module Bulma `notification`) et écrit sa cause dans la console: ni `void` ni `.catch` vide. Les
  ajouts et retraits d'organisation, appelés par le template et non signalés par Sonar, sont traités aussi. Quand
  l'action réussit mais pas la navigation ou le rechargement, le message le dit. Tests
  `error-handling.spec.ts`: les 18 tests d'erreur échouent sur l'ancien code; 36 tests sur 36 ensuite. Bundle de
  production 814 kB. Vérifié dans Chromium sans interface, back arrêté, pour les erreurs de chargement seulement
- [x] front: Karma (déprécié) remplacé par Vitest 5 avec `jsdom`, et builders `@angular-devkit/build-angular`
  migrés vers `@angular/build`. Justification, coût et vérifications: `docs/KARMA.md`. Pas de LTS pour Vitest:
  même règle que Gradle (dernière mineure, mise à jour régulière). `front/src/test-setup.ts` restaure les espions
  après chaque test. L'asset de test `favicon.ico`, absent, a disparu avec l'ancienne cible `test`
- [x] ci: seuils de couverture à 80 % pour le front et pour le back, sur tout le code et sur le code nouveau (job
  `coverage`, `scripts/coverage_gate.py`, décision du 26/11). Non bloquant jusqu'à ce que front et back
  atteignent 80 %; le passage en bloquant sera une PR dédiée (cf. « À faire »). Même formule que Sonar (lignes et
  branches, sources TypeScript et Java; templates HTML non comptés). Au 26/11: front 78,1 %, back 67,8 %
  (valeurs tronquées). Le Quality Gate Sonar reste inchangé et non bloquant
- [x] sonar: issues de l'état initial traitées, sauf les 2 `java:S6813` apparues ensuite (cf. « À faire »). Référence:
  `docs/quality/sonar-ci-scan-baseline/sonar-main-issues.json` (39 issues). Sur `main` à `9614697`: 0 bug,
  0 vulnérabilité, 0 % de duplication dans les trois projets
  - Lot 1, promesses non gérées: cf. l'entrée « front: promesses non gérées ».
  - Lot 2 (PR #30): `id` et `label for` sur les champs (`Web:InputWithoutLabelCheck`, `Web:S6853`), label et
    `thead` masqués visuellement (`is-sr-only`, `Web:S5256`), `Number.parseInt` (`S7773`), chargement des
    organisations dans `ngOnInit` (`S7059`). Analyse de `main` après la PR (projet unique): 0 bug, 2 code smells,
    couverture 75,6 %, duplication 1,3 %
  - Lot 3, duplication (PR #32): identifiant et horodatages communs dans `AuditedEntity` (`@MappedSuperclass`),
    après des tests de caractérisation des entités et du JSON de l'API (30 tests back verts)
  - Lot 3, couverture (PR #37 et #39): `main.ts`, `app.config.ts` et `app.routes.ts` exclus de la mesure (aucune
    logique propre; même liste dans `angular.json` et `front/sonar-project.properties`, ils restent analysés), puis
    tests des appels HTTP des deux services (50 tests front verts). Couverture du projet front: 79,4 % après les
    exclusions, 97,6 % après les tests
