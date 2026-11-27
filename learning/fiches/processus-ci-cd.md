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
6. La CI de `main` prépare des images candidates, les valide en staging, puis publie une **pré-version** si les
   commits le justifient. Le passage en production est un changement de statut de cette release.

## Les étapes, dans l'ordre

| Étape | Jobs | Question posée | Si elle échoue |
|---|---|---|---|
| 1. lint | `lint` | le code et le Dockerfile respectent-ils les règles ? | rien d'autre ne tourne pour le front et le back |
| 2. test et couverture | `test-front`, `test-back`, `infra-check` | le code fait-il ce qu'il doit ? l'infrastructure décrite est-elle valide ? | pas d'analyse ni de build |
| 3. qualité | `sonar-front`, `sonar-back`, `sonar-infra`, `coverage` | la qualité et la couverture suffisent-elles ? | couverture : bloquante ; Quality Gate Sonar : non bloquant |
| 4. build | `build-front`, `build-back`, `images`, `compose-test` | l'application se construit-elle et démarre-t-elle ? | pas de release |
| 5. bout en bout et scan | `e2e`, `scan` | les parcours fonctionnent-ils ? une vulnérabilité grave est-elle corrigeable ? | pas de release |
| 6. candidate (`main`) | `candidate` | quelles images, quel numéro ? | pas de release |
| 7. staging (PR et `main`) | `staging` | la version se déploie-t-elle, et sait-on revenir en arrière ? | pas de release |
| 8. pré-version (`main`) | `release`, `notify` | que publie-t-on ? | notification d'échec |
| 9. production | `promote.yml` | une personne a-t-elle décidé la mise en production ? | notification d'échec |

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
de couverture (pour Sonar), le front compilé et le JAR sortis des jobs de tests (repris par `images` sans
recompilation), puis les images (`docker save`). L'image **testée** et **scannée** est celle qui est
**publiée** : pas de reconstruction entre les deux, donc pas de différence possible.

## La durée, un compromis

Avec la CD, un run est passé d'environ 2 minutes à 10 ou 11 : le déploiement de démonstration en prenait à lui seul
4 à 5. D'où le choix de ne le lancer que sur les PR et `main` (un push de branche : environ 4 minutes). Pistes
pour aller plus loin : mettre en cache les couches Docker. L'image ne rejoue plus les tests (`bootJar`).

## La release

`scripts/release.py` lit les commits depuis le dernier tag `vX.Y.Z` et applique **SemVer** (*Semantic
Versioning*, versionnement sémantique `MAJEUR.MINEUR.CORRECTIF`) :

| Commits | Effet |
|---|---|
| `feat` | version mineure |
| `fix`, `perf`, `build` | correctif |
| `!` ou `BREAKING CHANGE:` | majeure (mineure tant que la version est en 0.x) |
| `docs`, `ci`, `test`, `chore`, `style`, `refactor` seuls | rien |

Les images vont sur **GHCR** (*GitHub Container Registry*). Elles y arrivent d'abord comme **candidates**. Après
validation en staging, la version est ajoutée aux **mêmes empreintes** (`sha256:…`), puis la release GitHub est
créée en **pré-version** avec le tag, les notes, le chart et les empreintes. La passer au statut de release
déclenche la mise en production.

## Le déploiement

Le job `staging` crée un cluster **kind** (*Kubernetes in Docker*) jetable, et y déploie dev puis staging avec
Terraform et Helm. Sur staging, il éprouve la sauvegarde, la restauration et les retours arrière. Le staging est
**identique à la production**, hors valeurs propres à l'installation, et les deux désignent les images par leur
empreinte : ce qui a été validé est exactement ce qui est mis en production.

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
