# Le processus CI/CD d'Orion

La **CI** (*Continuous Integration*, intégration continue) vérifie chaque changement dès qu'il est poussé. La
**CD** (*Continuous Delivery* ou *Deployment*, livraison ou déploiement continu) en tire une version publiable,
puis la déploie. Cette fiche suit un commit, du poste du développeur au déploiement.

## Le chemin d'un changement

1. Une branche courte (`front/…`, `back/…`, `ci/…`, `docs/…`), jamais directement `main`.
2. Des petits commits au format **conventional commits** : `type(portée): message`.
3. `push` : la CI tourne sur la branche. La pull request (PR) n'est ouverte que si elle est verte.
4. La PR relance la CI, avec les analyses SonarQube (SAST, *Static Application Security Testing*, analyse
   statique de sécurité).
5. Fusion en **rebase** : l'historique de `main` reste linéaire.
6. La CI de `main` publie une version si les commits le justifient, puis la déploie en démonstration.

## Les étapes, dans l'ordre

| Étape | Jobs | Question posée | Si elle échoue |
|---|---|---|---|
| 1. lint | `lint` | le code et le Dockerfile respectent-ils les règles ? | rien d'autre ne tourne pour le front et le back |
| 2. test et couverture | `test-front`, `test-back`, `infra-check` | le code fait-il ce qu'il doit ? l'infrastructure décrite est-elle valide ? | pas d'analyse ni de build |
| 3. qualité | `sonar-front`, `sonar-back`, `sonar-infra`, `coverage` | la qualité et la couverture suffisent-elles ? | couverture : bloquante ; Quality Gate Sonar : non bloquant |
| 4. build | `build-front`, `build-back`, `images`, `compose-test` | l'application se construit-elle et démarre-t-elle ? | pas de release |
| 5. bout en bout et scan | `e2e`, `scan` | les parcours fonctionnent-ils ? une vulnérabilité grave est-elle corrigeable ? | pas de release |
| 6. release (`main`) | `release` | que publie-t-on, sous quel numéro ? | pas de déploiement |
| 7. déploiement (PR et `main`) | `deploy-demo`, `notify` | la version se déploie-t-elle, et sait-on revenir en arrière ? | notification d'échec |

> **Pourquoi cet ordre ?** Les contrôles les moins chers d'abord : échouer en 20 secondes coûte moins qu'échouer
> après 5 minutes. Le prix : quand tout va bien, chaque étape attend la précédente.

## `needs` et `if` : le graphe des jobs

GitHub Actions n'a pas de « stages » : l'ordre vient de `needs`. Piège : si un job nécessaire est **sauté**
(Sonar hors PR et `main`), les suivants sont sautés aussi. D'où la forme :

```yaml
if: >-
  !cancelled() &&
  needs.images.result == 'success'
```

`!cancelled()` rend la main à la condition ; il faut alors vérifier chaque résultat explicitement.

## Les artefacts : construire une fois

Chaque job tourne sur une machine neuve. Ce qui doit passer de l'un à l'autre est un **artefact** : les rapports
de couverture (pour Sonar), puis les images (`docker save`). L'image **testée** et **scannée** est celle qui est
**publiée** : pas de reconstruction entre les deux, donc pas de différence possible.

## La durée, un compromis

Avec la CD, un run est passé d'environ 2 minutes à 10 ou 11 : le déploiement de démonstration en prend à lui seul
4 à 5. D'où le choix de ne le lancer que sur les PR et `main` (un push de branche : environ 4 minutes). Pistes
pour aller plus loin : mettre en cache les couches Docker, éviter de rejouer les tests dans l'image.

## La release

`scripts/release.py` lit les commits depuis le dernier tag `vX.Y.Z` et applique **SemVer** (*Semantic
Versioning*, versionnement sémantique `MAJEUR.MINEUR.CORRECTIF`) :

| Commits | Effet |
|---|---|
| `feat` | version mineure |
| `fix`, `perf`, `build` | correctif |
| `!` ou `BREAKING CHANGE:` | majeure (mineure tant que la version est en 0.x) |
| `docs`, `ci`, `test`, `chore`, `style`, `refactor` seuls | rien |

Les images vont sur **GHCR** (*GitHub Container Registry*), puis la release GitHub crée le tag, les notes et le
paquet du chart. Le tag vient en dernier : il n'existe que pour une version complète.

## Le déploiement

`deploy-demo` crée un cluster **kind** (*Kubernetes in Docker*) jetable, et y déploie dev, staging et production
avec Terraform et Helm. Sur staging, il éprouve la sauvegarde, la restauration et les retours arrière.

> **Limite à connaître.** Un cluster jetable prouve que le déploiement **fonctionne** ; il n'y a pas encore
> d'environnement permanent que l'on puisse visiter.

## Les secours

| Panne | Secours |
|---|---|
| la nouvelle version ne démarre pas | Helm annule de lui-même |
| elle démarre mais ne répond pas bien | le test de déploiement échoue, `helm rollback` |
| les données sont abîmées | restauration d'une sauvegarde (`scripts/restore.sh`) |
| l'automatisation est en panne | workflow « Livraison manuelle de secours », ou `scripts/deploy.sh` depuis un poste |

## Mesurer : les quatre indicateurs DORA

DORA (*DevOps Research and Assessment*) suit : la **fréquence de déploiement**, le **délai de livraison** (*lead
time*), le **taux d'échec des changements** et le **temps de rétablissement**. Orion ne les mesure pas encore.

## Dans Orion

- Le pipeline : [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) ; secours manuel :
  [`manual-delivery.yml`](../../.github/workflows/manual-delivery.yml) ; rescan hebdomadaire :
  [`security-scan.yml`](../../.github/workflows/security-scan.yml).
- Le schéma : [`schema_pipeline_ci_cd.png`](../../docs/livrables/schema_pipeline_ci_cd.png).
- Le déploiement : [`docs/DEPLOIEMENT.md`](../../docs/DEPLOIEMENT.md).

## À retenir

1. La CI vérifie, la CD publie et déploie ; les contrôles rapides passent en premier.
2. On publie l'image qu'on a testée, jamais une reconstruction.
3. Le numéro de version se calcule à partir des commits : leur format est un contrat.
4. Un déploiement n'est fini qu'après un test de santé, avec un retour arrière prévu et **éprouvé**.
