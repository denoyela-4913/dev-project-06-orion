# Backlog

## À faire

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
- [ ] sonar: traiter les issues de l'état initial (39 avec le scan CI: 24 bugs, 9 code smells, 6 vulnérabilités)
  - Sources: `docs/quality/sonar-ci-scan-baseline/sonar-main-issues.json` (scan CI, 39 issues, à utiliser) et
    `docs/quality/0.0.1-initial-state/sonar-main-issues.json` (analyse automatique, 35 issues). L'écart de 4 issues
    vient d'une analyse plus précise (cf. `docs/quality/sonar-ci-scan-baseline/README.md`), pas d'un changement de code.
  - Vulnérabilités du `Dockerfile` (`S6505`, `S8543`, `S6471`): traitées, cf. « Fait ». À confirmer sur l'analyse de `main`.
  - `back/build.gradle` (`S8569`): traité, cf. « Fait » (`gradle.lockfile`). À confirmer sur l'analyse Sonar de `main`.
  - `front/src/index.html` (`S5725`): traité, cf. « Fait » (Bulma installé via npm).
  - Bugs du front (24): promesses non gérées (`typescript:S9383`, 16, dont 4 sur `router.navigate(...)` visibles
    seulement avec le scan CI), champs de formulaire sans label (`Web:InputWithoutLabelCheck`, 7), tableau sans
    en-têtes `<th>` (`Web:S5256`, 1).
  - Duplication (1,7 %): 14 lignes dupliquées dans chacun de `Organization.java` et `Person.java`, à examiner.
  - Code smells (9): labels de formulaire (`Web:S6853`, 6), opération asynchrone dans un constructeur
    (`typescript:S7059`, 1), `Number.parseInt` à préférer à `parseInt` (`typescript:S7773`, 2).
  - À faire de préférence après la migration d'Angular, pour ne pas corriger deux fois du code touché par `ng update`
    (migration faite, cf. « Fait »).
  - Au 26/11, `main` a aussi 2 code smells `java:S6813` (injection par champ, `InitialDataFixture.java` lignes 14
    et 17), hors de ces lots: préférer l'injection par constructeur.
  - Lots, dans l'ordre décidé (une branche `front/…` par lot, tests qui échouent d'abord):
    1. promesses non gérées (`typescript:S9383`, 16 au départ, 13 sur `main` avant le lot): fait, cf. « Fait ».
       Fermeture des issues à confirmer sur l'analyse de `main`
    2. accessibilité et petites corrections: labels de formulaire (`Web:InputWithoutLabelCheck` ×7, `Web:S6853` ×6),
       `<th>` du tableau (`Web:S5256`), `Number.parseInt` (`S7773` ×2), opération asynchrone dans le constructeur (`S7059`)
    3. couverture de tests (le gate Sonar de `main` était en échec pour `new_coverage` = 0 %, à relire sur l'analyse
       de `main` après la PR #14) et duplication `Organization.java` / `Person.java`
  - Le jalon `v0.1.0` (tag et cliché Sonar dans `docs/quality/`) vient après ces trois lots.
- [ ] ci: améliorer la précision de l'analyse Java de Sonar (`sonar.java.libraries`)
  - Constat: le scan signale `Missing 'sonar.java.libraries'` et des types non résolus, car le scanner générique
    (choisi pour garder un seul projet Sonar) ne connaît pas le classpath Gradle, contrairement au plugin
    `org.sonarqube`.
  - Piste: une tâche Gradle qui écrit le classpath de compilation, passé au scan via `-Dsonar.java.libraries=...`.
  - À faire après la migration de Spring Boot (le classpath change), et à comparer au nombre d'issues Java actuel.
- [ ] front: corriger les défauts d'affichage et de navigation relevés pendant le lot des promesses (26/11)
  - Une correction par commit, avec un test qui échoue d'abord. Aucun n'est signalé par les issues Sonar traitées
    dans les lots ci-dessus. Priorité non décidée.
  - Vu à l'écran (front lancé sans le back):
    - tableau de bord: après un échec de chargement, « No person yet » et « No organization yet » s'affichent sous
      les messages d'erreur, comme si les listes étaient vides;
    - page d'une organisation: après un échec de chargement, le titre est `Organization ""`. La page d'une personne
      a le même modèle de titre (non vu à l'écran).
  - Vu à la lecture du code, non reproduit dans le navigateur:
    - tableau de bord: le lien « Create one » des organisations vise `organization/new` (singulier,
      `main-dashboard.component.html`). Aucune route ne correspond: la route `**` renvoie à l'accueil;
    - page d'une personne: le `(click)` du bouton « + » est sur le `<span>` intérieur et non sur le `<button>`. Un
      clic sur le bord du bouton, ou son activation au clavier, n'appelle pas `addSelectedOrganization()`. Le
      bouton est aussi dans le formulaire sans `type="button"`;
    - page d'une personne: le message « Phone must be a valid phone number. » attend une erreur `tel` qu'aucun
      validateur ne produit.
- [ ] sécurité: auditer le back et les images, puis scanner dans la CI
  - Back (Gradle) et images Docker n'ont pas encore été analysés.
  - Ajouter un scan de vulnérabilités dans la CI une fois les mises à jour faites, pour ne pas les réintroduire.
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

- [ ] ci: un Quality Gate Sonar par partie (front et back), proposition non décidée
  - Demande de l'utilisateur (26/11): un gate pour le front et un pour le back. SonarQube Cloud applique un gate par
    projet: il faut deux projets Sonar pour le même dépôt (support des monorepos), deux scans avec chacun son
    rapport de couverture. Reste à décider où rattacher le Dockerfile, les workflows et les scripts, et à vérifier
    la limite de projets du plan.
  - Conditions proposées par partie: couverture ≥ 80 % et 0 nouvelle vulnérabilité sur le code nouveau (approche
    recommandée par Sonar), plus un plancher de couverture globale (condition « code global » dans un gate personnalisé, copie de
    « Sonar way »; seuil fixe à relever à la main). État au 26/11:
    front 70,4 %, back 67,9 %.
  - Seuils décidés le 26/11 (80 % par partie, tout le code et code nouveau), appliqués par le job `coverage` de la
    CI (cf. « Fait »), sans second projet Sonar. Les deux gates Sonar restent une proposition. Livrables (Modèle 2, §2.6, R3,
    schéma) alignés le 26/11.
  - À faire avec le passage du gate en bloquant (`sonar.qualitygate.wait=true`); changera l'historique Sonar
    (nouveaux projets): garder les clichés `docs/quality/` comme référence.
- [ ] ci: passer les seuils de couverture en mode bloquant, par une PR dédiée (décidé le 26/11)
  - Condition d'ouverture: le front ET le back atteignent 80 % sur tout leur code (le job `coverage` le signale par
    un avertissement). Au 26/11: front 78,1 %, back 67,8 %.
  - Changement: `COVERAGE_BLOCKING: "true"` dans le job `coverage` de `ci.yml`, et commentaires à jour (`ci.yml`,
    `docs/SESSION.md`). Les 4 taux deviennent bloquants: tout le code et code nouveau, pour le front et le back.
  - La CI de cette PR tourne déjà en mode bloquant: elle doit être verte.
  - Le Quality Gate Sonar n'est pas concerné (`sonar.qualitygate.wait`, protection de `main`: non décidés).

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
  Reste: `build-back` (`./gradlew build`) relance les tests du back
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
