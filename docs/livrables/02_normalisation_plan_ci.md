---
title: "Normalisation du processus de développement et plan de mise en œuvre de la chaîne CI"
subtitle: "Projet Orion – Option B – version 01"
date: "19/11/2026"
---

# 1. Introduction

## 1.1 Objectifs

Définir des règles communes (code, versions, revue, CI, tests, sécurité, documentation) pour que chaque
livraison de l'application Full-Stack d'Orion soit **automatisée, répétable et vérifiée**, puis planifier la
mise en œuvre de la chaîne CI. Les équipes Dev et Ops appliquent les mêmes règles et lisent les mêmes
résultats.

## 1.2 Contexte

Voir le document de veille et d'audit (Modèle 1). Résumé : application au deuxième sprint ; CI limitée à tests
et build ; analyse de sécurité faite par les Ops après livraison ; déploiement manuel ; Dev peu expérimentés en
Java. L'état initial (tag `v0.0.1`) comptait 90 vulnérabilités npm dont 5 critiques, 35 issues SonarQube
(6 vulnérabilités) et une couverture de 37,1 %.

## 1.3 État initial du pipeline (description)

Pipeline d'origine (`.gitlab-ci.yml`), 2 stages et 4 jobs :

| Stage | Job | Image | Contenu |
|---|---|---|---|
| test | test-front | `cypress/browsers:latest` | `npm ci`, tests Karma en Chrome headless |
| test | test-back | `gradle:jdk17` | `./gradlew test` |
| build | build-front | `node` (latest) | `npm ci`, `ng build --optimization` |
| build | build-back | `gradle:jdk17` | `./gradlew build` |

Défauts : images non versionnées (`latest`), aucune analyse (sécurité, statique, lint), aucune image
produite ni publiée, aucun déploiement, aucune notification, aucune mesure.

# 2. Normes et bonnes pratiques

## 2.1 Principes de base

- **Automatisation** : toute opération répétée devient un job ou un script versionné.
- **Répétabilité** : versions et digests épinglés ; verrous (`package-lock.json`, `gradle.lockfile`).
- **Sécurité au plus tôt (shift-left)** : les contrôles tournent côté Dev, avant la livraison aux Ops.
- **Qualité** : pas de fusion sans CI verte ; couverture et Quality Gate suivis.
- **Justification** : tout choix technique est motivé dans un commentaire ou un message de commit.

## 2.2 Conventions d'écriture de code et règles de style

| Zone | Règle | Outil de contrôle |
|---|---|---|
| Front (Angular / TypeScript) | Guide de style Angular ; pas de promesse non gérée ; champs de formulaire avec label | ESLint (`angular-eslint`), SonarQube |
| Back (Java 21 / Spring Boot) | Conventions Java usuelles, couches contrôleur / service / dépôt, pas de logique dans les contrôleurs | Checkstyle, SpotBugs, SonarQube |
| Dockerfile | Mot-clé `AS` en majuscules, un stage par cible, utilisateur non root | hadolint, SonarQube |
| Scripts | Bash : `set -euo pipefail`, ShellCheck ; Python : tests `pytest` | ShellCheck, pytest |
| Commits | Conventional commits (`feat:`, `fix:`, `ci:`, `docs:`, `build:`) | contrôle en revue |

## 2.3 Gestion des versions

- **Modèle de branches** : GitHub Flow / trunk-based. Une branche `main` toujours livrable et des branches
  courtes. Choix justifié par la petite équipe (6 personnes), la fréquence de livraison souhaitée et
  l'absence de plusieurs versions maintenues en parallèle.
- **Nommage** : `front/…`, `back/…`, `ci/…`, `docs/…`, `fix/…`, selon le périmètre.
- **Fusion** : par pull request, en **rebase** pour garder un historique linéaire ; la branche est supprimée.
- **Versionnement** : Semantic Versioning (`MAJEUR.MINEUR.CORRECTIF`) ; tags `vX.Y.Z` ; génération
  automatisée à terme à partir des conventional commits.
- **Épinglage** : images de base et actions CI par version **et** digest/SHA, version en commentaire ;
  versions LTS dont le support dépasse 05/2027 ; Dependabot hebdomadaire.

## 2.4 Revue de code

- Toute modification passe par une pull request. **Au moins 1 approbation** d'un autre membre de l'équipe
  (un Ops relit les changements d'infrastructure, un Dev relit le code applicatif).
- Critères d'acceptation : CI verte, Quality Gate SonarQube vert, pas de CVE critique ou haute corrigeable,
  tests ajoutés pour tout correctif (un test qui échoue sans le correctif).
- La PR n'est ouverte que lorsque la CI de la branche est verte.
- Protection de `main` : pas de push direct, pas de fusion si un contrôle obligatoire échoue.

## 2.5 Intégration continue

- Déclenchement : à chaque push de branche et à chaque pull request.
- Fréquence d'intégration : au moins une PR par jour de travail sur une fonctionnalité ; branches de moins de
  quelques jours.
- Critère de réussite : tous les jobs obligatoires verts (lint, tests, build, scans).
- Outil : GitHub Actions (workflow validé) ; équivalent GitLab CI maintenu pour la livraison (voir 3.5, risque
  R2).
- Durée de référence mesurée (sans cache) : environ **108 s** par run (min 99 s, max 116 s).

## 2.6 Tests

| Type | Outil | Déclenchement | Cible |
|---|---|---|---|
| Unitaires back | JUnit (Gradle) | chaque push | couverture du code nouveau ≥ 80 % |
| Unitaires front | Karma / Jasmine (remplacement à l'étude) | chaque push | couverture du code nouveau ≥ 80 % |
| Intégration back | Spring Boot Test | chaque push | endpoints principaux |
| Scripts d'automatisation | pytest, Bash Unit, ShellCheck | chaque push | chaque script testé |
| Sécurité | SonarQube, Trivy | PR, `main`, hebdomadaire | 0 vulnérabilité critique/haute |
| Déploiement | script de test de déploiement (santé HTTP) | après déploiement | application répond |

Les tests de bout en bout et de performance seront ajoutés avec la partie 2 (déploiement, charge).

## 2.7 Sécurité

- **SAST** : SonarQube à chaque PR et sur `main`.
- **Dépendances et images** : Trivy (dépendances, Dockerfile, images) ; scan hebdomadaire planifié.
- **Secrets** : stockés dans les secrets de la plateforme CI (jamais dans le dépôt) ; jeton SonarQube en
  secret ; détection de secrets par Trivy.
- **Images** : épinglées, exécutées sans root, construites avec `npm ci --ignore-scripts`.
- **Droits** : jetons de CI au moindre privilège.
- **Gestion des vulnérabilités** : critique = correction avant fusion ; haute = correction sous 7 jours ;
  moyenne et basse = traitement planifié dans le backlog.

## 2.8 Documentation

- README technique à jour : configuration, tests, déploiement du pipeline ; but, fonctionnement et paramètres de
  chaque script.
- `docs/BACKLOG.md` et `docs/SESSION.md` : tâches et état courant.
- `docs/quality/` : clichés SonarQube par jalon (`v0.0.1`, `v0.0.2`, …).
- Documentation CI/CD complète : template fourni, complété au fil des étapes.

# 3. Plan de mise en œuvre

## 3.1 Objectifs

Obtenir une chaîne CI/CD qui, à chaque PR : vérifie (lint, tests, SonarQube, Trivy), construit les images,
les publie et les déploie sur l'environnement de démonstration, avec notification du résultat et possibilité de
déclencher manuellement une livraison en cas de panne de l'automatisation.

## 3.2 Étapes

### 3.2.1 Étape 1 : Pipeline CI de base

- **Description** : tests et build du front et du back, images et actions épinglées, Node 24 et Java 21.
- **Responsables** : Dev (lead : Roubina).
- **Livrables** : workflow CI fonctionnel ; mesure de durée de référence.
- **État** : **fait** (GitHub Actions).

### 3.2.2 Étape 2 : Contrôles qualité et sécurité

- **Description** : SonarQube avec couverture (non bloquant), Trivy (dépendances, Dockerfile, images), lint
  (ESLint, Checkstyle/SpotBugs, hadolint).
- **Responsables** : Dev, avec Ops pour les seuils Trivy.
- **Livrables** : jobs `lint`, `trivy`, `sonar` ; rapport des résultats ; seuils documentés.
- **État** : SonarQube **fait** ; Trivy et lint **à faire**.

### 3.2.3 Étape 3 : Scripts d'automatisation

- **Description** : scripts Bash/Python pour la gestion des dépendances, l'exécution des tests, le
  déploiement, la sauvegarde et la notification des résultats ; tests des scripts (ShellCheck, pytest).
- **Responsables** : Ops (Bash, Ansible) avec un Dev pour Python.
- **Livrables** : dossier `scripts/` documenté dans le README (but, fonctionnement, paramètres).

### 3.2.4 Étape 4 : Livraison automatisée de l'image

- **Description** : publication des images dans un registre, versionnement SemVer automatique, livraison
  manuelle de secours.
- **Responsables** : Dev et Ops.
- **Livrables** : images dans le registre ; tag de version ; notes de release.

### 3.2.5 Étape 5 : Déploiement automatisé

- **Description** : déploiement sur l'environnement de démonstration (Docker, puis Kubernetes + Helm, puis
  Terraform + Ansible, cf. partie 2) ; test de déploiement ; procédure de rollback ; sauvegarde.
- **Responsables** : Ops.
- **Livrables** : charts Helm, fichiers Terraform, playbooks Ansible, pipeline CD.

## 3.3 Ressources nécessaires

| Ressource | Détail |
|---|---|
| Personnel | 4 Dev, 2 Ops (un DevOps pour la mise en place) |
| Plateforme CI | GitHub Actions ; dépôt GitLab public à fournir (voir risque R2) |
| Qualité | SonarQube Cloud (compte et jeton), Trivy (open source) |
| Registre | registre de la plateforme CI ; Harbor à confirmer |
| Environnement | environnement de démonstration ; local : Docker, Minikube |
| Budget | principalement du temps ; services gratuits (Free Tier) |

## 3.4 Calendrier prévisionnel

Dans un fonctionnement normal (ressources disponibles, sans blocage).

| Semaine | Étape | Résultat attendu |
|---|---|---|
| S1 : 23–27/11/2026 | Étape 2 (Trivy, lint, Sonar non bloquant), début Étape 3 | jobs de contrôle verts sur PR |
| S2 : 30/11–04/12/2026 | Étape 3 (scripts), Étape 4 (registre, image livrée) | image publiée à chaque fusion |
| S3 : 07–11/12/2026 | Étape 4 (versionnement), début Étape 5 | version générée automatiquement |
| S4–S5 : 14–25/12/2026 | Étape 5 (déploiement, rollback, sauvegarde) | déploiement automatisé, rollback testé |
| Jalon `v0.1.0` | Quality Gate bloquant | gate vert sur `main` |

## 3.5 Gestion des risques

| # | Risque | Probabilité | Mesure d'atténuation |
|---|---|---|---|
| R1 | Équipe Dev peu expérimentée en Java : sous-estimation des corrections | Haute | Sonar non bloquant d'abord ; revue systématique ; formation courte ; pair programming avec un Ops/senior |
| R2 | Le sujet exige GitLab CI alors que le dépôt de travail est sur GitHub | Haute | Maintenir un `.gitlab-ci.yml` équivalent et un miroir GitLab public ; décision à prendre avant la livraison |
| R3 | Couverture de tests faible (37,1 %) : Quality Gate difficile à tenir | Moyenne | Seuil de 80 % sur le **code nouveau** seulement ; ajout de tests à chaque correctif |
| R4 | Faux positifs Trivy qui bloquent la CI | Moyenne | Fichier d'exceptions justifiées (`.trivyignore`) ; bloquer seulement les CVE corrigeables |
| R5 | Panne de l'automatisation lors d'une livraison urgente | Moyenne | Livraison manuelle de secours documentée |
| R6 | Dépendance à un service externe (Sonar, registre) | Moyenne | Jetons en secrets ; Harbor à moyen terme ; mesure de disponibilité |
| R7 | Savoir de sécurité concentré chez 2 Ops | Moyenne | Partage via la CI et la documentation ; relecture croisée |

# 4. Conclusion

## 4.1 Synthèse

La normalisation fixe des règles uniques de code, de versions, de revue, de tests et de sécurité, et les fait
appliquer par la CI. Elle transforme un processus manuel (contrôle des CVE par les Ops après livraison) en un
processus automatisé, répétable et mesurable.

## 4.2 Prochaines étapes

- Terminer les étapes 2 et 3 du plan (Trivy, lint, scripts) ; passer le Quality Gate en mode bloquant.
- Compléter la documentation CI/CD : stratégie de tests, schémas d'architecture IaC, plan de sécurité,
  plans de release, de rollback et de sauvegarde.
- Mettre en œuvre la partie 2 : Docker, Kubernetes, Helm, Terraform, Ansible, monitoring, métriques DORA.
- Réviser ce document à chaque jalon.

# Annexe : schéma initial du pipeline cible

À reproduire dans draw.io pour la version finale.

```
push / pull request
        |
   [ lint ]  ESLint | Checkstyle/SpotBugs | hadolint
        |
   [ test ]  test-front (Karma)  |  test-back (JUnit)
        |
   [ build ] build-front | build-back | docker build (3 cibles)
        |
   [ scan ]  SonarQube (+ couverture) | Trivy (deps, Dockerfile, images)
        |   -- gate non bloquant -> bloquant (v0.1.0)
        |
   merge sur main --> [ release ]  version SemVer + tag + image dans le registre
        |
   [ deploy démo ] Helm / Ansible  --> [ test de déploiement ] --> [ notification ]
        |
   échec --> rollback automatique (helm rollback)  |  livraison manuelle de secours
```
