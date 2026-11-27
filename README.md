<p align="center">
   <img src="./front/src/favicon.png" width="192px" />
</p>

# MicroCRM (P5 - Expert DevOps - Gérez le cycle de vie de développement logiciel)

MicroCRM est une application de démonstration basique ayant pour être objectif de servir de socle pour le module "P5 - Expert DevOps".

L'application MicroCRM est une implémentation simplifiée d'un ["CRM" (Customer Relationship Management)](https://fr.wikipedia.org/wiki/Gestion_de_la_relation_client). Les fonctionnalités sont limitées à la création, édition et la visualisations des individus liés à des organisations.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

> L'API n'a **pas d'authentification** : ne pas l'exposer sur Internet (cf. [`docs/SECURITE.md`](./docs/SECURITE.md)).

## Code source

### Organisation

Ce [monorepo](https://en.wikipedia.org/wiki/Monorepo) contient :

| Dossier | Contenu |
|---|---|
| `back/` | serveur : Java 21, Spring Boot 4.1, Spring Data REST, Gradle |
| `front/` | client : Angular 22, tests Vitest |
| `e2e/` | tests de bout en bout (Playwright) |
| `Dockerfile`, `misc/docker/` | images `front` et `back` |
| `deploy/` | Docker Compose, chart Helm, Terraform |
| `scripts/` | tests de déploiement, déploiement, secours, release, qualité |
| `.github/workflows/` | pipeline CI/CD (GitHub Actions) |
| `docs/` | déploiement, sécurité, tests, livrables, backlog |
| `learning/` | fiches et flashcards |

Le fichier [`.gitlab-ci.yml`](./.gitlab-ci.yml) d'origine est conservé pour mémoire ; il n'est plus maintenu (ses
options de test du front datent de Karma). Le pipeline en service est celui de GitHub Actions.

### Démarrer avec les sources

Prérequis : [JDK 21](https://openjdk.org/) pour le back ; [Node.js 24](https://nodejs.org/) pour le front.

```shell
# Serveur, sur http://localhost:8080 (Ctrl+C pour l'arrêter)
cd back && ./gradlew bootRun          # Windows : gradlew.bat bootRun

# Client, sur http://localhost:4200, dans un autre terminal
cd front && npm ci --ignore-scripts && npm start
```

### Démarrer avec Docker seul

```shell
scripts/compose.sh dev up -d --build --wait     # http://localhost:4280
scripts/compose.sh dev down
```

Environnements `staging` et `production`, images et réglages : [`docs/DEPLOIEMENT.md`](./docs/DEPLOIEMENT.md).

### Tests et contrôles

```shell
cd back && ./gradlew clean build                      # tests, Checkstyle, SpotBugs
cd front && npm run lint && npm test -- --watch=false --coverage
python3 -m unittest discover -s scripts
scripts/compose.sh dev up -d --build --wait && scripts/e2e.sh
scripts/trivy.sh repo                                  # sécurité (Docker requis)
```

Détail : [`docs/TESTS.md`](./docs/TESTS.md).

## Pipeline CI/CD

![Pipeline CI/CD](./docs/livrables/schema_pipeline_ci_cd.png)

À chaque push qui touche autre chose que la documentation (`**.md`, `docs/`, `learning/`) : lint, tests, couverture, analyses, construction et test des images, scan de sécurité. Sur les PR et
`main`, dev et staging sont déployés sur un cluster jetable. Sur `main`, quand les commits le justifient et que le
staging est validé, une **pré-version** est publiée (images sur GHCR, release GitHub). La passer au statut de
release déploie en production les mêmes images, désignées par leur empreinte. La promotion sait installer la production, pas encore la mettre à
niveau (pour cela : `scripts/deploy.sh`). Détail : [`docs/DEPLOIEMENT.md`](./docs/DEPLOIEMENT.md).

## Images Docker

Lancer des conteneurs, avec Docker seul (l'image est construite si elle manque, `--build` la reconstruit) :

```shell
scripts/run_all.sh                       # back et front : http://localhost:4280
scripts/run_all.sh --stop
scripts/run_back.sh --port 9090          # back seul : http://localhost:9090
scripts/run_front.sh --api-url http://localhost:9090     # front seul : http://localhost:4280
```

| Script | Paramètres principaux (liste complète en tête de chaque script) |
|---|---|
| `run_all.sh` | `--front-port` (4280), `--back-port` (8080), `--https`, `--data VOLUME`, `--bind`, `--name`, `--build`, `--stop` |
| `run_back.sh` | `--port` (8080), `--cors`, `--data VOLUME`, `--env`, `--bind`, `--name`, `--image`, `--build`, `--stop` |
| `run_front.sh` | `--port` (4280), `--https`, `--api-url` ou `--upstream`, `--env`, `--bind`, `--name`, `--image`, `--build`, `--stop` |

Les ports n'écoutent que sur le poste (`127.0.0.1`) sauf `--bind` : l'API n'a pas d'authentification. `run_back.sh`
et `run_front.sh` passent à `docker run` ce qui suit `--` (ex. `-- --memory 1g`). Avec un front lancé seul sur un
autre port que 4280, déclarer son origine au back (`run_back.sh --cors http://localhost:<port>`).

Les images se construisent aussi directement : `docker build --target front -t microcrm-front:local .` (de même
avec `back`). À la main, le Dockerfile compile lui-même ; en CI, les images reprennent les produits des jobs de tests.
