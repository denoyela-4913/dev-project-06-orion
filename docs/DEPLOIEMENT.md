# Déploiement de MicroCRM

Comment construire, lancer et déployer l'application. Le pipeline complet est décrit par
`docs/livrables/schema_pipeline_ci_cd.png`.

## 1. Images Docker

Un seul `Dockerfile`, trois cibles :

| Cible | Contenu | Ports | Usage |
|---|---|---|---|
| `front` | Caddy et le front compilé ; relaie `/api` vers le back | 80, 443 | déploiement |
| `back` | JRE 21 et le JAR Spring Boot | 8080 | déploiement |
| `standalone` | les deux, lancés par supervisord | 80, 443, 8080 | démonstration en un seul conteneur |

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

Fichiers dans `deploy/compose/` : un socle (`compose.yaml`), un fichier par environnement, un fichier de
protections commun à staging et production, et les variables dans `env/`. Le script `scripts/compose.sh` choisit
les bons fichiers et isole chaque environnement (nom de projet `microcrm-<env>`).

```bash
scripts/compose.sh dev up -d --build --wait      # http://localhost:4280 (API aussi sur :8080)
scripts/smoke_test.sh http://localhost:4280      # test de déploiement
scripts/compose.sh dev down                      # arrêt ; ajouter -v pour effacer les volumes
```

| | dev | staging | production |
|---|---|---|---|
| Accès | HTTP local 4280 | HTTP local 4281 | HTTPS 443 (80 redirige) |
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

Chart : `deploy/helm/microcrm/`. Une valeur commune (`values.yaml`) et un fichier par environnement.

| | dev | staging | production |
|---|---|---|---|
| Instances front / back | 1 / 1 | 2 / 1 | 3 / 1 |
| Données | en mémoire | volume 1 Gi | volume 5 Gi |
| Ingress et TLS | non | non | oui (domaine à fixer) |
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
| `scripts/backup.sh <espace> [release]` | sauvegarde à froid du volume dans `backups/` (coupure d'une à deux minutes) |
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

## 6. Releases

Sur `main`, le job `release` publie une version quand les commits depuis le dernier tag le justifient
(`scripts/release.py`, tests dans `scripts/test_release.py`) :

| Commits depuis le dernier tag | Version |
|---|---|
| `type!:` ou `BREAKING CHANGE:` | majeure (la mineure avant 1.0.0) |
| `feat` | mineure |
| `fix`, `perf`, `build` | correctif |
| seulement `docs`, `ci`, `test`, `chore`, `style`, `refactor` | pas de release |

Il publie sur GHCR `ghcr.io/<propriétaire>/<dépôt>/microcrm-{front,back,standalone}:X.Y.Z` (les images testées et
scannées dans le même run, sans reconstruction ; pas d'étiquette `latest`), puis crée la release GitHub : tag
`vX.Y.Z`, notes générées depuis les commits et paquet du chart Helm. Pour connaître la prochaine version sans rien
publier : `python3 scripts/release.py` (écrit `release-notes.md`, ignoré par git).

Si l'envoi s'interrompt, relancer le job : à partir de la deuxième tentative, les images déjà envoyées sont
remplacées. Un nouveau paquet GHCR peut être privé par défaut : sa visibilité se règle dans GitHub (backlog).

## 7. Dans la CI

Le job `images` construit les trois cibles et les transmet par artefact ; `compose-test` lance les trois
environnements Compose et le test de déploiement.

## 8. Limites connues

- La base est HSQLDB, interne au back : **une seule instance** du back, et une courte coupure à chaque mise à jour
  quand les données sont conservées. Une base externe (PostgreSQL) est en attente de décision (backlog).
- L'API n'a pas d'authentification (backlog) : ne pas l'exposer sur Internet en l'état.
