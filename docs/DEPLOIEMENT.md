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

## 4. Dans la CI

Le job `images` construit les trois cibles et les transmet par artefact ; `compose-test` lance les trois
environnements Compose et le test de déploiement.

## 5. Limites connues

- La base est HSQLDB, interne au back : **une seule instance** du back, et une courte coupure à chaque mise à jour
  quand les données sont conservées. Une base externe (PostgreSQL) est en attente de décision (backlog).
- L'API n'a pas d'authentification (backlog) : ne pas l'exposer sur Internet en l'état.
