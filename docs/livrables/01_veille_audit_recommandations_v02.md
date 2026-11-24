---
title: "Document de veille technologique, d'audit et de recommandations"
subtitle: "Projet Orion – Option B – version 02"
date: "19/11/2026"
---

# 1. Introduction

## 1.1 Objectif

Ce document analyse la chaîne d'intégration et de livraison actuelle de l'application Full-Stack d'Orion
(Angular + Spring Boot), recense les technologies susceptibles de l'améliorer et formule des
recommandations priorisées et planifiées. Il sert de base à la mise en place du pipeline CI/CD, puis à la
documentation complète (Modèle 2, plan de CD).

Il répond aux trois points demandés par Maria (CTO) :

- identifier les goulots d'étranglement et les lacunes de sécurité ;
- proposer des solutions modernes et efficaces ;
- planifier l'implémentation avec un calendrier précis.

## 1.2 Rappel du contexte

L'application est en début de vie (deuxième sprint). Deux équipes interviennent :

- **Dev** (4 personnes) : bon niveau sur Angular et npm, **débutants sur Java/Spring Boot, Gradle, JUnit et
  HyperSQL**. Ils produisent trois images Docker (front, back, « tout-en-un »).
- **Ops** (2 personnes) : très bon niveau en Bash, bon niveau sur Ansible, Docker, Debian, TestInfra ;
  niveau moyen sur PostgreSQL. Ils reçoivent un numéro de version d'image, la scannent avec Trivy, puis la
  déploient **à la main** avec des commandes Docker sur l'environnement de démonstration.

Les deux équipes décrivent le même irritant : la quasi-totalité des opérations est manuelle, et le pipeline
CI se limite au strict minimum (tests puis build, sans analyse). Les CVE signalées par les Ops après la
première livraison ont déjà retardé le premier déploiement. Les Ops demandent un registre d'images interne et
des contrôles de sécurité **avant** la transmission des images ; les Dev demandent des outils d'analyse
statique pour ne pas introduire de mauvaises pratiques Java.

# 2. Rapport de veille technologique

## 2.1 Méthodologie

1. **Cadrage** : à partir des deux sondages, liste des besoins (sécurité avant livraison, analyse statique,
   automatisation du déploiement, registre interne, reproductibilité des builds).
2. **Recherche** : pour chaque besoin, identification des outils de référence, en privilégiant la
   documentation officielle des éditeurs, les référentiels reconnus (OWASP Top 10, SonarSource Rules) et
   endoflife.date pour les dates de fin de support.
3. **Comparaison** : matrice avantages/inconvénients par catégorie, selon deux critères : applicabilité au
   contexte Orion (équipe de 6 personnes, compétences Java limitées, outils déjà connus des Ops) et rapport
   coût/bénéfice (licence, temps de mise en place, charge de maintenance).
4. **Vérification** : chaque outil retenu est essayé sur le dépôt réel (build, tests, scan) avant d'être
   recommandé.

Sources principales : documentation GitLab CI et GitHub Actions, documentation Trivy, documentation
SonarQube / SonarQube Cloud, documentation Docker et BuildKit, documentation Harbor, documentation
Kubernetes, Helm, Terraform et Ansible, OWASP Top 10.

## 2.2 Technologies évaluées

### 2.2.1 Trivy

- **Description** : scanner open source (Aqua Security) de vulnérabilités, de mauvaises configurations et de
  secrets.
- **Catégorisation** : scan de sécurité (SCA / images / IaC).
- **Fonctionnalités clés** : scan d'images de conteneurs, du système de fichiers et des dépendances
  (`package-lock.json`, `gradle.lockfile`), des fichiers IaC (Dockerfile, Terraform, Kubernetes), détection de
  secrets, génération de SBOM, code de sortie configurable selon la gravité.
- **Cas d'usage** : étape CI qui échoue si une CVE critique ou haute corrigeable est trouvée ; audit
  hebdomadaire planifié.
- **Pertinence Orion** : **déjà utilisé par les Ops** : le déplacer côté Dev supprime le « retour à
  l'envoyeur ».

### 2.2.2 SonarQube (SonarQube Cloud)

- **Description** : plateforme d'analyse de la qualité et de la sécurité du code (SAST), avec Quality Gate.
- **Catégorisation** : analyse statique.
- **Fonctionnalités clés** : règles Java, TypeScript, Docker, Web ; détection de bugs, vulnérabilités, code
  smells et hotspots de sécurité ; couverture de tests (JaCoCo, lcov) ; Quality Gate bloquant sur le code
  nouveau ; décoration des pull requests.
- **Cas d'usage** : analyse à chaque PR et sur la branche principale ; suivi de la dette technique.
- **Pertinence Orion** : **exigé par Maria** ; répond au besoin Dev (équipe débutante en Java).

### 2.2.3 Linters : ESLint, Checkstyle / SpotBugs, hadolint

- **Description** : analyseurs syntaxiques et de style, rapides, exécutables en local et en CI.
- **Catégorisation** : lint.
- **Fonctionnalités clés** : ESLint (avec `angular-eslint`) pour TypeScript et templates Angular ;
  Checkstyle (style) et SpotBugs (bugs) pour Java ; hadolint pour les Dockerfile (versions non épinglées,
  mauvaises pratiques). Les avertissements `FromAsCasing` observés au build Docker sont du même ordre.
- **Cas d'usage** : job CI rapide, exécuté avant les tests.

### 2.2.4 Registres d'images : Docker Hub, GHCR, GitLab Container Registry, Harbor

- **Description** : dépôts d'images OCI. Harbor est open source et auto-hébergeable ; les autres sont des
  services hébergés.
- **Catégorisation** : registre.
- **Fonctionnalités clés (Harbor)** : contrôle d'accès par projet, scan de vulnérabilités intégré
  (Trivy), signature, réplication, quotas, politiques de rétention.
- **Cas d'usage** : stockage des images livrées aux Ops, promotion d'une image testée vers
  l'environnement de démonstration.

### 2.2.5 GitLab CI et GitHub Actions

- **Description** : deux moteurs de CI/CD déclaratifs (YAML).
- **Catégorisation** : plateforme CI/CD.
- **Fonctionnalités clés** : jobs, dépendances entre jobs (`stages` / `needs`), caches, artefacts,
  environnements, registre de conteneurs intégré, modèles réutilisables.
- **Cas d'usage** : pipeline à chaque push et à chaque PR/MR.
- **Contexte Orion** : le dépôt contient le `.gitlab-ci.yml` d'origine et le workflow GitHub Actions qui le
  remplace (voir 2.3.5).

### 2.2.6 Docker Compose, Kubernetes, Helm, Minikube

- **Description** : Compose décrit des conteneurs sur une machine ; Kubernetes orchestre des conteneurs sur un
  cluster ; Helm empaquette les manifestes Kubernetes en charts ; Minikube fournit un cluster local.
- **Catégorisation** : orchestration.
- **Fonctionnalités clés (Kubernetes)** : déploiements déclaratifs, mises à jour progressives (rolling update)
  et retour arrière (`rollout undo`), sondes de santé, mise à l'échelle, secrets et ConfigMaps.
- **Cas d'usage** : déploiement reproductible de front, back et base de données sur l'environnement de
  démonstration.

### 2.2.7 Terraform et Ansible

- **Description** : Terraform décrit et crée l'infrastructure (état déclaratif) ; Ansible configure les
  machines et déploie (procédural, idempotent).
- **Catégorisation** : Infrastructure as Code.
- **Pertinence Orion** : Ansible est déjà maîtrisé par les Ops (niveau « bon »).

## 2.3 Matrices comparatives

### 2.3.1 Scan de sécurité des images et dépendances

| Comparé à | Trivy | Grype |
|---|---|---|
| **Trivy** | – | **Avantages de Grype vs Trivy** : outil centré sur les vulnérabilités, simple. **Inconvénients** : pas de scan IaC ni de secrets intégré ; **inconnu des Ops**. |
| **Grype** | **Avantages de Trivy vs Grype** : déjà utilisé par les Ops ; couvre images, dépendances, IaC et secrets avec un seul outil. **Inconvénients** : base de vulnérabilités à télécharger à chaque run (à mettre en cache). | – |

**Choix : Trivy.**

### 2.3.2 Analyse statique du code

| Comparé à | SonarQube | Checkstyle + SpotBugs + ESLint seuls |
|---|---|---|
| **SonarQube** | – | **Avantages des linters seuls vs SonarQube** : gratuits, locaux, sans compte ni serveur. **Inconvénients** : un outil par langage, pas de Quality Gate, pas de suivi de la couverture, pas d'historique. |
| **Linters seuls** | **Avantages de SonarQube vs linters** : une vue unique Java + TypeScript + Docker, Quality Gate, couverture, hotspots de sécurité ; imposé par Maria. **Inconvénients** : service externe (SonarQube Cloud) ou serveur à héberger ; un jeton à protéger. | – |

**Choix : SonarQube (obligatoire) + linters complémentaires**, car ils ne se recouvrent pas
entièrement (ESLint et hadolint tournent en quelques secondes, avant les tests).

### 2.3.3 Registre d'images

| Comparé à | Docker Hub | GHCR / GitLab Registry | Harbor |
|---|---|---|---|
| **Docker Hub** | – | **Avantage vs Docker Hub** : intégré à la plateforme CI, authentification par le jeton du pipeline. **Inconvénient** : toujours externe. | **Avantages** : interne, contrôle d'accès, scan, rétention. **Inconvénients** : un service de plus à héberger et à mettre à jour. |
| **GHCR / GitLab Registry** | **Avantage vs GHCR** : très répandu. **Inconvénients** : quotas de téléchargement, dépendance externe (point soulevé par les Ops). | – | **Avantages** : interne, scan natif. **Inconvénients** : exploitation à charge des Ops. |
| **Harbor** | **Avantage vs Harbor** : aucune exploitation. **Inconvénients** : externe. | **Avantage vs Harbor** : aucune exploitation, démarrage immédiat. **Inconvénient** : externe. | – |

**Choix : registre de la plateforme CI (GHCR ou GitLab Registry) à court terme**, car il permet de livrer
rapidement ; **Harbor à confirmer avec les Ops** pour répondre à leur demande de registre interne.

### 2.3.4 Orchestration

| Comparé à | Docker Compose | Kubernetes + Helm |
|---|---|---|
| **Docker Compose** | – | **Avantages de Kubernetes vs Compose** : rolling update, rollback, sondes de santé, mise à l'échelle, secrets, standard du marché. **Inconvénients** : plus complexe, courbe d'apprentissage. |
| **Kubernetes + Helm** | **Avantages de Compose vs Kubernetes** : très simple, adapté à une machine unique. **Inconvénients** : pas de rollback ni de mise à l'échelle natifs, peu de résilience. | – |

**Choix : Kubernetes + Helm (Minikube en local)**, en partie 2 du projet. Compose reste utile en développement.

### 2.3.5 Plateforme CI

| Comparé à | GitLab CI | GitHub Actions |
|---|---|---|
| **GitLab CI** | – | **Avantages de GitHub Actions vs GitLab CI** : dépôt déjà hébergé sur GitHub ; large catalogue d'actions ; runners hébergés prêts à l'emploi. **Inconvénients** : actions tierces à épingler par SHA pour la sécurité de la chaîne d'approvisionnement. |
| **GitHub Actions** | **Avantages de GitLab CI vs GitHub Actions** : plateforme unique (code, CI, registre, environnements) ; **imposé par le sujet** (livrable : lien GitLab public). **Inconvénients** : un dépôt de plus à synchroniser si le code reste sur GitHub. | – |

**Choix actuel : GitHub Actions** (le dépôt de travail est sur GitHub, le workflow est validé et épinglé).
**Point ouvert** : le livrable doit être un dépôt GitLab public. Deux options : miroir du dépôt vers GitLab
avec le `.gitlab-ci.yml` maintenu, ou bascule complète. Cette décision est à arbitrer avant la livraison.

# 3. Audit des processus de développement

## 3.1 Objectifs

- Identifier **les goulots d'étranglement** et les lacunes en matière de sécurité.
- Proposer l'intégration de **solutions modernes** et efficaces.
- **Planifier** les étapes d'implémentation avec un calendrier précis.

## 3.2 Méthodologie

- Lecture des sondages des équipes Dev et Ops du projet Orion.
- Lecture du README et du `.gitlab-ci.yml` d'origine.
- Exécution des commandes de build et de run des deux parties du logiciel (back et front) et construction des
  images Docker, avec relevé des avertissements (journaux conservés dans `docs/logbook/0.0.1-initial-state/`).
- Analyse SonarQube Cloud de la branche `main` (cliché du 18/11/2026, tag `v0.0.1`).
- Approche SWOT (voir 3.4).

## 3.3 Processus audités

### 3.3.1 Développement d'une version en environnement staging

- **Description** : traitement d'une liste d'évolutions précise, avec évaluation de la charge et
  priorisation avec le product owner ; démonstration de mi-itération ; intégration des retours et des
  derniers correctifs ; génération des images et envoi des références à l'équipe Ops.
- **Forces** : bonne maîtrise du périmètre ; revue intermédiaire qui cadre le développement.
- **Faiblesses** : aucune analyse statique du code ; équipe peu expérimentée sur le back-end et la base de
  données ; pipeline réduit à tests + build.
- **Risques** : découverte des CVE à la livraison aux Ops ; mauvaises pratiques Java installées sans
  détection.
- **Constats chiffrés (état initial, tag `v0.0.1`)** :
    - `npm install` (front) : **90 vulnérabilités (7 low, 27 moderate, 51 high, 5 critical)** ;
    - SonarQube : **35 issues** à l'analyse automatique (39 avec le scan CI), dont **6 vulnérabilités**,
      24 bugs et 9 code smells ; note de sécurité **C** ; couverture mesurée à **37,1 %** avec le scan CI.

### 3.3.2 Déploiement d'une version sur l'environnement de démonstration

- **Description** : réception d'un numéro de version d'image ; scan Trivy ; déploiement manuel avec les
  commandes Docker. L'application n'est pas encore en production : le processus ne concerne que
  l'environnement de démonstration.
- **Forces** : le déploiement fonctionne ; les Ops contrôlent les CVE avant de déployer.
- **Faiblesses** : analyse et déploiement manuels ; communication par e-mail et en direct ; aucun
  registre : l'échange passe par des références de version.
- **Risques** : processus chronophage et source d'erreurs humaines ; retour à l'envoyeur à chaque CVE.
- **Constats chiffrés** : 5 avertissements au `docker build` (`FromAsCasing`, lignes 1, 10, 18, 32 et 44) ;
  l'image `node` du build front n'a pas de version (donc `latest`) : le build n'est pas reproductible et
  l'image n'est pas vérifiable. Cela correspond à des règles SonarQube (`S6505`, `S8543`, `S6471`).

## 3.4 Synthèse (SWOT)

| | Positif | Négatif |
|---|---|---|
| **Interne** | **Forces** : périmètre maîtrisé, revue de mi-itération ; Ops expérimentés (Bash, Ansible, Docker, Trivy) ; Dev à l'aise en Angular ; dépôt unique, petite équipe. | **Faiblesses** : Dev débutants en Java/Gradle/JUnit/HyperSQL ; CI minimale ; tout est manuel côté Ops ; échanges par e-mail ; couverture de tests de 37 %. |
| **Externe** | **Opportunités** : outils déjà en place mais sous-exploités (Trivy chez les Ops) ; SonarQube imposé et gratuit pour du code public ; plateformes CI avec registre intégré ; possibilité de mutualiser Kubernetes/Helm/Terraform. | **Menaces** : dette technique (composants en fin de support : Angular 17, Spring Boot 3.2, Alpine 3.19, Node 20) ; chaîne d'approvisionnement (dépendances transitives, images non épinglées) ; **concentration du savoir de sécurité chez les deux Ops** ; HyperSQL en développement contre PostgreSQL chez les Ops (écarts de comportement). |

**Synthèse.** Le développement est bien organisé (revue de périmètre, revue intermédiaire), mais le
back-end et la base de données sont peu maîtrisés. Les vulnérabilités ne sont testées que par les Ops, après
livraison. Le processus Ops est extrêmement limité et entièrement manuel.

# 4. Recommandations

## 4.1 Objectifs

| # | Objectif | Axe |
|---|---|---|
| O1 | Supprimer toutes les vulnérabilités critiques, et si possible toutes les autres. | Sécurité |
| O2 | N'utiliser dans les Dockerfile que des images avec version et digest SHA. | Sécurité |
| O3 | Automatiser la CI, de la validation du code jusqu'à l'image publiée. | Fréquence de livraison |
| O4 | Intégrer les vérifications (sécurité, analyse statique, lint) dans la CI. | Fluidité |
| O5 | Automatiser la génération de la release (version, image, notes). | Fluidité |
| O6 | Automatiser le déploiement sur l'environnement de démonstration. | Fluidité |

## 4.2 Recommandations pour l'automatisation et la chaîne CI

### 4.2.1 Intégrer les vérifications de sécurité dans la CI (Trivy)

- **Description** : lancer Trivy dans la CI, côté Dev, sur les dépendances (`package-lock.json`,
  `gradle.lockfile`), le Dockerfile et les images construites.
- **Raisonnement** : les problèmes de sécurité doivent être trouvés au plus tôt, sans attendre le retour des
  Ops. Trivy est déjà l'outil des Ops : les deux équipes parleront des mêmes résultats.
- **Implémentation** : job CI après le build des images ; échec si CVE de gravité CRITICAL ou HIGH ayant un
  correctif ; scan planifié chaque semaine (les CVE apparaissent même sans changement de code) ;
  mise en cache de la base de vulnérabilités.
- **Impacts** : le développement n'est plus bloqué à chaque livraison ; réduction du risque de CVE à la
  réception par les Ops.

### 4.2.2 Intégrer l'analyse statique du code dans la CI (SonarQube)

- **Description** : lancer SonarQube (SonarQube Cloud) à chaque pull request et sur `main`, avec couverture
  de tests (JaCoCo pour le back, lcov pour le front).
- **Raisonnement** : risque de dérive sur le back-end à cause du manque d'expérience Java / Spring Boot.
- **Implémentation** : job `sonar` avec jeton stocké en secret de la plateforme ; Quality Gate **non
  bloquant** d'abord, puis bloquant quand les correctifs auront ramené le projet à un niveau suffisant
  (voir calendrier).
- **Impacts** : les mauvaises pratiques sont détectées au fil de l'eau ; pas d'accumulation de dette
  technique ; indicateur partagé entre Dev et Ops.

### 4.2.3 Intégrer les vérifications lint dans la CI

- **Description** : lancer ESLint (front), Checkstyle/SpotBugs (back) et hadolint (Dockerfile).
- **Raisonnement** : détecter rapidement les problèmes de syntaxe, de style et certaines failles de sécurité
  avant même les tests ; les avertissements `FromAsCasing` au build Docker en sont un exemple.
- **Implémentation** : job `lint` en première étape (feedback en moins d'une minute).
- **Impacts** : code plus lisible et plus maintenable ; échecs rapides et peu coûteux.

### 4.2.4 Épingler et mettre à jour les briques (version + digest SHA)

- **Description** : toutes les images de base et les actions CI sont référencées par version **et** digest ;
  Dependabot propose les mises à jour.
- **Raisonnement** : un tag (`latest`, `node`) peut être déplacé ; sans épinglage, le build n'est ni
  reproductible ni vérifiable, et une image altérée pourrait être utilisée sans que personne ne le voie.
- **Implémentation** : `FROM image:version@sha256:…` ; versions LTS avec support au-delà de 05/2027 ;
  verrou Gradle ; `npm ci --ignore-scripts` ; Dependabot hebdomadaire avec délai de 7 jours avant
  proposition.
- **Impacts** : builds reproductibles ; les 5 CVE critiques du front et les 6 vulnérabilités Sonar de
  l'état initial sont corrigées sans intervention manuelle récurrente.

### 4.2.5 Automatiser la génération de la release et la livraison de l'image

- **Description** : la fusion d'une PR sur `main` déclenche le calcul de la version (SemVer), le tag, la
  construction des images et leur publication dans un registre.
- **Raisonnement** : le Dev ne passe plus par un échange de numéros de version par e-mail ; les Ops
  récupèrent une image déjà testée et scannée.
- **Implémentation** : versionnement automatique à partir des conventional commits ; publication des
  images dans le registre de la plateforme ; possibilité de **forcer une livraison manuelle** si
  l'automatisation tombe en panne.
- **Impacts** : délai de reprise réduit en cas de défaut urgent (lead time) ; plus de fréquence de
  livraison.

### 4.2.6 Déploiement automatisé : registre, Kubernetes, Helm, Terraform, Ansible

- **Description** : mettre en place un registre d'images (Harbor à confirmer, sinon registre de la
  plateforme), orchestrer avec Kubernetes et Helm, créer l'infrastructure avec Terraform, la configurer
  avec Ansible (déjà maîtrisé par les Ops).
- **Raisonnement** : libérer les Ops du déploiement manuel pour qu'ils se consacrent aux vérifications et aux
  processus ; rendre le déploiement et le rollback reproductibles.
- **Implémentation** : voir partie 2 du projet (Docker, Kubernetes, Terraform, Ansible).
- **Impacts** : baisse du taux d'erreur humaine ; mise à jour et retour arrière en une commande.

# 5. Conclusion

## 5.1 Synthèse des constats

Le développement est bien organisé mais il faut ajouter des contrôles automatisés, en particulier sur le
back-end et la base de données où l'équipe manque d'expérience. L'état initial affichait 90 vulnérabilités
front dont 5 critiques, 6 vulnérabilités SonarQube et des images non épinglées ; les CVE n'étaient testées
que par les Ops, après livraison.

Processus à mettre en place : vérifications de sécurité automatiques (Trivy), analyse statique automatique
(SonarQube), lint automatique, versions et digests épinglés, génération automatisée de la release,
déploiement automatisé.

## 5.2 Prochaines étapes (calendrier prévisionnel)

Le calendrier part de la semaine du 23/11/2026. La colonne « État » reflète le dépôt au 19/11/2026.

| Semaine | Priorité | Action | État au 19/11/2026 |
|---|---|---|---|
| **S1** (23–27/11) | P1 | Automatisation de la CI et livraison automatique de l'image aux Ops (reprise rapide en cas de défaut urgent). | CI de tests + build **en place** (GitHub Actions) ; publication d'image à faire. |
| S1 | P2 | Analyse statique du back (SonarQube) en mode non bloquant ; ajout de Trivy et lint. | SonarQube en place ; Trivy et lint à faire. |
| **S2** (30/11–04/12) | P3 | Automatiser toutes les opérations (dont sécurité) jusqu'au déploiement, avec **déclenchement manuel de secours**. | À faire. |
| S2 | P4 | Registre d'images (Harbor à confirmer, sinon registre de la plateforme). | À faire. |
| **S3** (07–11/12) | P5 | Versionnement automatique de la livraison à la fusion d'une PR. | À faire. |

Cas particulier : le passage du Quality Gate SonarQube en mode **bloquant** est prévu en S3, une fois les
issues du front traitées (état au 19/11/2026 : gate de `main` en échec sur la seule condition « couverture
du nouveau code »).

*Il n'est pas nécessaire d'implémenter toutes les recommandations dans le cadre du projet : la priorité est
donnée à P1 à P3.*
