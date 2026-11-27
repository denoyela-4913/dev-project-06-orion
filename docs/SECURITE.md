# Sécurité : audit et contrôles

## 1. Contrôles en place

| Contrôle | Où | Bloquant |
|---|---|---|
| Dépendances (verrous npm et Gradle), secrets, configurations | job `scan` (`scripts/trivy.sh repo`) | oui : critique ou haute avec correctif |
| Images `front`, `back` | job `scan` (`scripts/trivy.sh image …`) | oui : critique ou haute avec correctif |
| Rescan hebdomadaire (lundi) et à la demande | workflow `Scan de sécurité` | échec notifié par GitHub |
| Analyse statique (bugs, vulnérabilités, hotspots) | SonarQube Cloud, trois projets | non (Quality Gate non bloquant) |
| Bugs et style du Java | SpotBugs et Checkstyle (`./gradlew build`) | oui |
| TypeScript, templates, Dockerfile | job `lint` (ESLint, hadolint) | oui |
| Versions figées | verrous, images et actions épinglées par SHA ou digest, Dependabot | – |
| Droits de la CI | écriture réservée aux jobs `candidate` (registre), `release` (dépôt, registre), `notify` et au passage en production (commentaire), et à la livraison manuelle (registre) | – |
| Conteneurs | utilisateur non root, aucune capacité Linux, lecture seule en staging, production et Kubernetes ; niveau « restricted » imposé par Terraform | – |

En local : `scripts/trivy.sh repo` et `scripts/trivy.sh image <image>…` (Docker suffit).

### Pourquoi l'image de Trivy et pas son action GitHub

En mars 2026, la chaîne de publication de Trivy a été compromise : un binaire et des tags de ses actions GitHub ont
été remplacés par du code qui volait les secrets des pipelines
([avis de l'éditeur](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23),
[analyse de Microsoft](https://www.microsoft.com/en-us/security/blog/2026/03/24/detecting-investigating-defending-against-trivy-supply-chain-compromise/)).
La CI n'utilise donc que l'image officielle **0.76.2** (05/11/2026, release immuable), épinglée par **digest** dans
`scripts/trivy.sh`. Un digest ne peut pas être déplacé. Le scan des images donne à Trivy l'accès au Docker du
runner : le job qui le lance n'a aucun secret ni droit d'écriture.

## 2. Audit du 26/11/2026 (au soir)

Trivy 0.76.2, base de vulnérabilités du jour, seuil à partir de « moyenne » pour les dépendances et de « haute »
pour les images.

| Cible | Vulnérabilités | Secrets | Configurations |
|---|---|---|---|
| `back/gradle.lockfile` (critique, haute, moyenne) | 0 | – | – |
| `front/package-lock.json` (critique, haute, moyenne) | 0 | – | – |
| `Dockerfile` | – | – | 0 |
| Image `front` (Alpine 3.24.4 ; critique, haute) | 0 | 0 | – |
| Image `back` (Alpine 3.24.4 et JAR ; critique, haute) | 0 | 0 | – |
| Image `standalone` (critique, haute) | 0 | 0 | – |

Contrôle du contrôle : sur un verrou de test contenant `lodash 4.17.15`, le script sort bien en erreur.

**Contrôle du 27/11 sur les images publiées `0.2.2`** (lues depuis GHCR, utilisateur `10001`, étiquette de
révision égale au commit du tag) : 0 critique, 0 haute, **7 moyennes** par image dans les paquets Alpine (OpenSSL et
zlib, correctifs disponibles), suivies au backlog. L'audit du 26/11 ne les voyait pas pour les images, car il ne
portait sur elles qu'à partir du niveau « haute ».

C'est un état à une date donnée : de nouvelles vulnérabilités sont publiées en permanence, d'où le rescan
hebdomadaire. Référence de départ (`v0.0.1`) : 90 vulnérabilités npm, dont 5 critiques.

## 3. Risques connus, non traités

| Risque | État |
|---|---|
| **API sans authentification** : lecture et écriture de données personnelles par quiconque atteint le back (par le proxy `/api` du front compris) | en attente de décision (backlog) ; ne pas exposer sur Internet |
| `main` sans protection : une PR en échec reste fusionnable | en attente de décision (réglage du dépôt) |
| Quality Gates Sonar non bloquants | décision du 26/11 |
| Image de Trivy non suivie par Dependabot (référence dans un script) | mise à jour manuelle (backlog) |
| Images publiées sur GHCR lisibles sans authentification | attendu pour un dépôt public ; aucune donnée ni secret dans les images (scan de secrets) |
| Sauvegardes (données personnelles) en local, non chiffrées, non planifiées | à traiter avec l'hébergement (backlog) |
