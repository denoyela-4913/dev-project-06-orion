# Terraform

Déploie MicroCRM sur un cluster Kubernetes existant. Terraform ne crée pas le cluster ni de ressource payante :
aucun hébergement n'est choisi (cf. `docs/BACKLOG.md`).

```
deploy/terraform/
├── modules/
│   ├── platform/     espace de noms (niveau « restricted »), quota, valeurs par défaut des conteneurs ; tests/
│   └── microcrm/     release Helm du chart deploy/helm/microcrm
└── environments/
    ├── dev/          versions.tf, providers.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example
    ├── staging/
    └── production/
```

Chaque environnement a son dossier, donc **son propre état** : une erreur en dev ne peut pas modifier la
production. `dev` a son propre quota et ses réglages. **`staging` est identique à `production`** (même quota, même
`values-prodlike.yaml` du chart) : seules diffèrent les valeurs propres à une installation (origine publique,
domaine, Secret TLS). `scripts/check_parity.sh` le vérifie en CI.

## Utilisation

```bash
cd deploy/terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars     # puis l'adapter
terraform init
terraform plan
terraform apply
../../../../scripts/verify_deployment.sh "$(terraform output -raw namespace)"
```

Si les pods de la nouvelle version ne deviennent pas prêts, Helm revient à la révision précédente
(`atomic = true`) et `apply` échoue. Après un retour arrière fait à la main (`scripts/rollback.sh`), l'état
Terraform décrit encore l'ancienne demande : le prochain `apply` réappliquera la version configurée.

## Vérifications

```bash
terraform fmt -check -recursive deploy/terraform
(cd deploy/terraform/environments/staging && terraform init -backend=false && terraform validate)
(cd deploy/terraform/modules/platform && terraform init && terraform test)    # fournisseur simulé
```

La CI les lance dans le job `infra-check`. Les versions des fournisseurs sont figées par les fichiers
`.terraform.lock.hcl` (plateformes `linux_amd64` et `darwin_arm64`). Terraform n'a pas de LTS : suivre la dernière
mineure (1.17).

## État

L'état est **local** (`backend "local"`). Il convient à un seul poste ou à un cluster jetable de CI. Pour un
vrai environnement partagé, il faut un état distant, chiffré et verrouillé : décision liée à l'hébergement
(backlog). L'état peut contenir des valeurs sensibles : il est ignoré par git.
