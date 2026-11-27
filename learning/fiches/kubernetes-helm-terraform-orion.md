# Déployer Orion : Kubernetes, Helm, Terraform

**Kubernetes** (k8s) fait tourner des conteneurs sur un cluster et maintient l'état demandé. **Helm** génère les
manifestes à partir de gabarits et de valeurs. **Terraform** décrit l'infrastructure et applique les écarts.

## Les objets utilisés

| Objet | Rôle dans Orion |
|---|---|
| Namespace | un par environnement (`microcrm-dev`…) |
| Deployment | le front (1 à 3 instances) et le back (1 instance) |
| Service | une adresse stable devant les pods |
| PersistentVolumeClaim (PVC) | les données du back en staging et production |
| Ingress | l'entrée HTTP(S) en production |
| NetworkPolicy | seul le front peut joindre le back |
| PodDisruptionBudget | au moins un front disponible pendant une maintenance |
| ResourceQuota, LimitRange | plafonds et valeurs par défaut de l'environnement |

## La sécurité des pods

Le namespace impose le niveau **restricted** des *Pod Security Standards* : pas de root, pas de gain de droits,
capacités retirées, profil seccomp par défaut. Les conteneurs d'Orion n'ajoutent aucune capacité, ont un système
de fichiers en lecture seule et un stockage temporaire borné (`ephemeral-storage`).

## Une seule instance du back

La base HSQLDB vit **dans** le processus : deux instances auraient deux bases différentes. Le chart refuse donc
`back.replicas > 1`. Avec un volume, la stratégie est `Recreate` (l'ancien pod s'arrête avant le nouveau), d'où
une courte coupure. Lever la limite suppose une base externe (décision en attente).

## Helm

```
deploy/helm/microcrm/
├── Chart.yaml            version du chart et de l'application
├── values.yaml           valeurs communes
├── values-<env>.yaml     écarts par environnement
└── templates/            gabarits des objets
```

| Commande | Effet |
|---|---|
| `helm template` | affiche les manifestes sans rien déployer |
| `helm upgrade --install` | installe ou met à jour |
| `--atomic` (Helm 3) ou `--rollback-on-failure` (Helm 4) | annule si les pods ne deviennent pas prêts |
| `helm history`, `helm rollback` | révisions et retour arrière |

## Terraform

| Notion | Sens |
|---|---|
| *provider* | l'extension qui parle à un système (ici `kubernetes`, `helm`) |
| module | un groupe de ressources réutilisable |
| état (*state*) | ce que Terraform sait avoir créé |
| `plan` / `apply` | voir les changements / les appliquer |
| fichier `.terraform.lock.hcl` | versions et empreintes des providers |

Orion : un module `platform` (namespace et garde-fous), un module `microcrm` (la release Helm) et **un dossier
par environnement**, chacun avec son état.

> **Dérive.** Après un `helm rollback` manuel, l'état Terraform décrit encore l'ancienne demande : le prochain
> `apply` la réappliquera.

## Retour arrière et données

Un retour arrière remet les **manifestes** précédents, pas les **données**. La sauvegarde est faite **à froid** :
le back est arrêté, un pod temporaire monte le volume et copie son contenu, puis le back redémarre. Copier une base
en cours d'écriture ne garantit pas une copie cohérente.

## Dans Orion

[`deploy/helm/microcrm/`](../../deploy/helm/microcrm/), [`deploy/terraform/`](../../deploy/terraform/README.md),
[`scripts/deploy.sh`](../../scripts/deploy.sh), [`scripts/backup.sh`](../../scripts/backup.sh).

## À retenir

1. Helm paramètre les manifestes ; Terraform prépare l'environnement et installe le chart.
2. Un environnement, un état : une erreur en dev ne touche pas la production.
3. Un retour arrière ne restaure pas les données : il faut une sauvegarde, et l'avoir essayée.
