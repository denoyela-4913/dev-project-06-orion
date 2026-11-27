# Déploiement de MicroCRM

Comment construire, lancer et déployer l'application. Le pipeline complet est décrit par
`docs/livrables/schema_pipeline_ci_cd.png`.

## 1. Images Docker

Un seul `Dockerfile`, deux images :

| Cible | Contenu | Ports | Usage |
|---|---|---|---|
| `front` | Caddy et le front compilé ; relaie `/api` vers le back | 80, 443 | déploiement |
| `back` | JRE 21 et le JAR Spring Boot | 8080 | déploiement |

La compilation et l'assemblage des images sont séparés :

| Étape | Rôle |
|---|---|
| `front-build`, `back-build` | compilent (Node, Gradle). Les jobs `test-front` et `test-back` les construisent et y jouent les tests (`scripts/ci_test.sh <front\|back>`) |
| `front-dist`, `back-dist` | ne contiennent que le produit : front compilé, JAR |
| `front`, `back` | images finales, qui lisent le produit dans l'étape `-dist` |

- **À la main**, le produit vient de l'étape de compilation : `docker build --target back .` suffit.
- **En CI**, `test-front` et `test-back` publient ce produit en artefact (`dist-front`, `dist-back`). Le job
  `images` lance `scripts/build_images.sh artifacts` : `--build-context front-dist=…` remplace l'étape `-dist` par
  l'artefact, BuildKit saute la compilation, et le script échoue si elle a lieu quand même. L'image contient ainsi
  le produit sorti de l'étape où les tests ont tourné.

Le Dockerfile ne produit que le JAR (`./gradlew bootJar`) ; Checkstyle et SpotBugs sont exécutés par `build-back`.
Pour lancer les conteneurs avec Docker seul : `scripts/run_all.sh`, `run_back.sh`, `run_front.sh` (cf. README).

Toutes tournent sous l'utilisateur non root `10001`. Images de base épinglées par digest, paquets Alpine
épinglés à la mineure.

```bash
docker build --target front -t microcrm-front:local .
docker build --target back -t microcrm-back:local .
```

### Réglages à l'exécution (variables d'environnement)

| Variable | Image | Défaut | Rôle |
|---|---|---|---|
| `SITE_ADDRESS` | front | `*` (HTTPS, certificat interne) | adresse servie par Caddy ; `:8080` pour du HTTP seul derrière un proxy ou un ingress ; un nom de domaine pour un certificat automatique |
| `API_BASE_URL` | front | `http://localhost:8080` | adresse de l'API vue par le navigateur ; `/api` pour passer par le front |
| `API_UPSTREAM` | front | `localhost:8080` | où Caddy relaie `/api` |
| `APP_CORS_ALLOWED_ORIGINS` | back | `http://localhost:4200,https://localhost` | origines autorisées ; mettre l'origine publique du front |
| `SPRING_DATASOURCE_URL` | back | base en mémoire | `jdbc:hsqldb:file:/data/microcrm;shutdown=true;hsqldb.write_delay=false` pour conserver les données dans `/data` |

`API_BASE_URL` est lu au démarrage : la même image sert à tous les environnements, sans reconstruction.

### Santé

| Chemin | Image | Sens |
|---|---|---|
| `/healthz` | front | Caddy répond |
| `/actuator/health/liveness` | back | le processus répond |
| `/actuator/health/readiness` | back | prêt à recevoir du trafic |

Seul `health` est exposé par Actuator, sans détail (`HealthTests`).

## 2. Docker Compose

Fichiers dans `deploy/compose/` : un socle (`compose.yaml`), un fichier pour dev, un fichier **commun à staging et
production** (`compose.hardened.yaml`), et les variables dans `env/`. Staging et production utilisent les mêmes
fichiers : seules les valeurs d'une installation (domaine, origine publique, ports) diffèrent. Le script `scripts/compose.sh` choisit
les bons fichiers et isole chaque environnement (nom de projet `microcrm-<env>`).

```bash
scripts/compose.sh dev up -d --build --wait      # http://localhost:4280 (API aussi sur :8080)
scripts/smoke_test.sh http://localhost:4280      # test de déploiement
scripts/compose.sh dev down                      # arrêt ; ajouter -v pour effacer les volumes
```

| | dev | staging | production |
|---|---|---|---|
| Accès | HTTP local 4280 | HTTPS local 4443 (certificat interne) | HTTPS 443 (80 redirige) |
| Back publié | oui (8080) | non | non |
| Données | en mémoire | volume `back-data` | volume `back-data` |
| Protections (lecture seule, droits retirés, mémoire limitée, redémarrage) | non | oui | oui |

En production, remplacer `localhost` par le domaine dans `deploy/compose/env/production.env`. Aucun secret n'est
nécessaire aujourd'hui ; ces fichiers sont versionnés et ne doivent pas en recevoir.

Pour lancer des images déjà construites : `FRONT_IMAGE=… BACK_IMAGE=… scripts/compose.sh staging up -d --no-build`.

## 3. Test de déploiement

`scripts/smoke_test.sh <URL du front>` vérifie à travers le front : santé du back et du front, page et routes de
l'application, réglage `/api`, lecture de l'API, puis création et suppression d'une personne avec l'en-tête
`Origin` d'un navigateur (détecte un réglage CORS faux). `SMOKE_INSECURE=1` accepte le certificat interne.

## 4. Kubernetes avec Helm

Chart : `deploy/helm/microcrm/`. Une valeur commune (`values.yaml`), un fichier partagé par staging et production
(`values-prodlike.yaml`), et un fichier par environnement. **Le staging est identique à la production** :
`values-staging.yaml` et `values-production.yaml` ne portent que l'origine publique, le domaine et le Secret TLS.
`scripts/check_parity.sh` le vérifie en CI pour Helm, Terraform et Compose. Un réglage de ces deux environnements
s'écrit donc dans le fichier partagé.

| | dev | staging | production |
|---|---|---|---|
| Instances front / back | 1 / 1 | 3 / 1 | 3 / 1 |
| Données | en mémoire | volume 5 Gi | volume 5 Gi |
| Ingress et TLS (coupé sur le cluster de démonstration) | non | oui (domaine à fixer) | oui (domaine à fixer) |
| NetworkPolicy (back joignable du front seul) | non | oui | oui |

Tous les pods tournent sans root, système de fichiers en lecture seule, sans aucune capacité Linux, avec un
stockage temporaire borné. Le chart est compatible avec le niveau `restricted` des normes de sécurité des pods.

Les images viennent d'un registre donné par `images.repositoryPrefix` (jamais écrit en dur dans le dépôt).

### Déployer, vérifier, revenir en arrière

Prérequis : `kubectl` et `helm` (3 ou 4), le contexte `kubectl` pointant sur le cluster.

```bash
scripts/deploy.sh staging 0.1.0 --set images.repositoryPrefix=ghcr.io/<propriétaire>/<dépôt>/
```

`deploy.sh` enchaîne : sauvegarde des données (si une version tourne avec un volume), `helm upgrade --install`
(annulé par Helm si les pods ne deviennent pas prêts), test de déploiement par port-forward, et `helm rollback`
si ce test échoue. Il ne dépend pas de la CI : c'est la **livraison manuelle de secours**.

| Script | Rôle |
|---|---|
| `scripts/verify_deployment.sh <espace>` | test de déploiement d'une release installée |
| `scripts/rollback.sh <espace> [release] [révision]` | retour arrière puis vérification |
| `scripts/backup.sh <espace> [release]` | sauvegarde à froid du volume dans `backups/` (coupure d'environ une minute) |
| `CONFIRM=oui scripts/restore.sh <archive> <espace>` | **remplace** les données par l'archive |

Un retour arrière ne touche pas aux données : si une version a modifié le schéma, restaurer la sauvegarde. Les
sauvegardes contiennent des données personnelles : elles sont créées lisibles par leur seul propriétaire,
ignorées par git, et restent sur la machine qui les lance (stockage distant et planification : backlog).

### Essais faits en local (minikube, 27/11/2026)

Installation puis mise à jour avec sauvegarde ; restauration (les données reviennent à l'état sauvegardé) ; version
dont l'image n'existe pas (annulée par Helm, service et données intacts) ; version qui démarre mais échoue au test
(retour arrière automatique puis vérification). Ces essais utilisaient Helm 3.22 ; la CI utilise Helm 4.

## 5. Terraform

Terraform prépare l'environnement (espace de noms au niveau `restricted`, quota) puis y installe le chart. Code
découpé en deux modules et un dossier par environnement, chacun avec son état : voir
[`deploy/terraform/README.md`](../deploy/terraform/README.md).

Essai en local (minikube, 27/11/2026) : `apply` de staging, pods prêts et test de déploiement réussi (hors écriture,
qui a révélé le défaut d'origine corrigé dans le Caddyfile).

## 6. De la candidate à la production

Les images sont construites **une seule fois**. À partir du staging, elles sont désignées par leur **empreinte**
(`sha256:…`) : les pods de staging et de production exécutent les mêmes binaires.

| Étape | Job ou workflow | Ce qui se passe |
|---|---|---|
| 1. candidate (`main`) | `candidate` | si les commits justifient une version : envoi sur GHCR des images testées et scannées, sous l'étiquette `candidate-<commit>`, et relevé de leurs empreintes |
| 2. validation | `staging` | dev puis staging déployés ; avec une candidate, le cluster tire les images depuis GHCR **par leur empreinte** |
| 3. pré-version (`main`) | `release` | **seulement si le staging a réussi** : étiquette `X.Y.Z` ajoutée aux mêmes empreintes, puis **pré-version** GitHub (tag `vX.Y.Z`, notes, chart Helm, `images-digests.env`) |
| 4. production | `promote.yml` | déclenché quand **une personne** change le statut de la pré-version en release ; déploie les empreintes de `images-digests.env`, sans rien reconstruire |

Version (`scripts/release.py`, tests dans `scripts/test_release.py`) :

| Commits depuis le dernier tag | Version |
|---|---|
| `type!:` ou `BREAKING CHANGE:` | majeure (la mineure avant 1.0.0) |
| `feat` | mineure |
| `fix`, `perf`, `build` | correctif |
| seulement `docs`, `ci`, `test`, `chore`, `style`, `refactor` | pas de release |

### Passer une version en production

Sur la page de la release, décocher *Set as a pre-release* et cocher *Set as the latest release*, ou :

```bash
gh release edit vX.Y.Z --prerelease=false --latest
```

- Promouvoir la version **la plus récente** validée : rien n'empêche de promouvoir une pré-version plus ancienne,
  qui serait alors déployée.
- Si le déploiement en production échoue, la release **garde son statut** : l'échec est signalé par la
  notification. Relancer le workflow une fois la cause corrigée.
- Une release sans `images-digests.env` (antérieure à ce fonctionnement, ou créée à la main) n'est pas déployée.

`scripts/candidate_images.sh` envoie les candidates puis ajoute l'étiquette de version ; il vérifie que l'empreinte
n'a pas changé et refuse de réattribuer une version à d'autres images. Pas d'étiquette `latest` sur les images.
Les étiquettes `candidate-*` restent sur GHCR, publiques comme les versions : leur nettoyage n'est pas automatisé.
Pour connaître la prochaine version sans rien publier : `python3 scripts/release.py` (écrit `release-notes.md`,
ignoré par git).

## 7. Déploiement de démonstration

Les jobs `staging` (dev puis staging) et le workflow de production créent chacun un cluster **kind** dans le runner
et lancent `scripts/deploy_demo.sh` : pour chaque environnement, `terraform apply`, contrôle que les pods désignent
les empreintes attendues quand elles sont fournies, test de déploiement par port-forward, puis `terraform destroy`.
Sur staging, `scripts/test_recovery.sh` éprouve en plus la sauvegarde et la restauration, l'annulation d'une version
qui ne démarre pas et le retour arrière d'une version qui échoue au test. Sur une PR, les images du run sont
chargées dans le cluster : **le déploiement par empreinte ne s'exécute que sur `main`**.

**Ce que cela prouve, et ses limites** : le chart, le code Terraform, les images et les procédures de secours
fonctionnent sur un vrai cluster Kubernetes. Mais ces clusters sont **jetables**, y compris la « production » : il
n'y a pas d'environnement permanent, ni de domaine, de certificat public ou de stockage durable. Le choix d'un
hébergement est en attente (backlog).

Rejouer en local sur un cluster de test (sans empreintes, les images doivent y être chargées) :

```bash
KUBE_CONTEXT=<contexte de test> scripts/deploy_demo.sh <version> [préfixe de registre]
```

Variables facultatives : `ENVIRONMENTS="dev staging"`, `BACK_DIGEST` et `FRONT_DIGEST` (ensemble).

### Notification

Le job `notify` écrit le résultat dans le résumé du run. Sur `main`, il ajoute un commentaire au commit (GitHub
prévient les personnes abonnées) et appelle le webhook du secret `NOTIFY_WEBHOOK_URL` s'il existe (format
`{"text": …}`). Un workflow en échec déclenche en plus la notification habituelle de GitHub.

### Livraison manuelle de secours

**Limite** : avec *publish*, ce secours reconstruit les images et les publie **avant** tout déploiement, sans release
ni `images-digests.env`. Il ne respecte pas la règle « staging d'abord » et ne passe pas par `promote.yml`.

| Situation | Que faire |
|---|---|
| L'automatisation n'a pas livré, GitHub Actions fonctionne | onglet *Actions*, workflow **Livraison manuelle de secours** : version `X.Y.Z`, cocher *publish* pour construire, scanner et publier |
| GitHub Actions est indisponible | depuis un poste : `scripts/build_images.sh`, `scripts/trivy.sh image …`, `docker login ghcr.io`, `scripts/publish_images.sh ghcr.io/<propriétaire>/<dépôt>/ X.Y.Z`, puis `scripts/deploy.sh <env> X.Y.Z --set images.repositoryPrefix=…` |

## 8. Dans la CI

| Étape du schéma | Jobs |
|---|---|
| 1. lint | `lint` |
| 2. test et couverture | `test-front`, `test-back`, et `infra-check` (chart, scripts, Terraform) |
| 3. qualité | `sonar-front`, `sonar-back`, `sonar-infra`, `coverage` |
| 4. build | `build-front`, `build-back` (avec Checkstyle et SpotBugs), `images`, `compose-test` |
| 5. scan | `scan` ; rescan hebdomadaire : workflow *Scan de sécurité* |
| 6. candidate (`main`) | `candidate` |
| 7. validation en staging (PR et `main`) | `staging` |
| 8. pré-version (`main`) | `release`, `notify` |
| 9. production (changement de statut de la release) | workflow *Passage en production* |

## 9. Limites connues

- La base est HSQLDB, interne au back : **une seule instance** du back, et une courte coupure à chaque mise à jour
  quand les données sont conservées. Une base externe (PostgreSQL) est en attente de décision (backlog).
- L'API n'a pas d'authentification (backlog) : ne pas l'exposer sur Internet en l'état.
