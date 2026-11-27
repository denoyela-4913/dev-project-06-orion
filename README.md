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
| `Dockerfile`, `misc/docker/` | images `front`, `back` et `standalone` |
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

À chaque push : lint, tests, couverture, analyses, construction et test des images, scan de sécurité, et
déploiement de démonstration sur un cluster jetable. Sur `main`, une version est publiée quand les commits le
justifient (images sur GHCR, release GitHub). Détail : [`docs/DEPLOIEMENT.md`](./docs/DEPLOIEMENT.md).

## Images Docker

| Cible | Construire | Lancer |
|---|---|---|
| front | `docker build --target front -t orion-microcrm-front:latest .` | `docker run -it --rm -p 80:80 -p 443:443 orion-microcrm-front:latest` |
| back | `docker build --target back -t orion-microcrm-back:latest .` | `docker run -it --rm -p 8080:8080 orion-microcrm-back:latest` |
| tout en un | `docker build --target standalone -t orion-microcrm-standalone:latest .` | `docker run -it --rm -p 8080:8080 -p 80:80 -p 443:443 orion-microcrm-standalone:latest` |

L'application est sur https://localhost (certificat interne de Caddy) et l'API sur http://localhost:8080.
