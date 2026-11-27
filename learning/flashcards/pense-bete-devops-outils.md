# Flashcards — Pense-bête DevOps : Terraform, Ansible, Docker, Compose, Kubernetes, Helm

Fiche associée : [pense-bete-devops-outils](../fiches/pense-bete-devops-outils.md)

Q: Quelle question chacun des six outils résout-il : Terraform, Ansible, Docker, Compose, Kubernetes, Helm ?
R: Terraform : quelle infra créer. Ansible : comment configurer les machines. Docker : comment empaqueter l'appli. Compose : comment la lancer sur une machine. Kubernetes : comment la faire tourner sur un cluster. Helm : comment réutiliser et paramétrer les manifestes k8s.

---

Q: Dans quel ordre enchaîne-t-on les outils pour un déploiement complet ?
R: Terraform (infra), Ansible (configuration des machines), Docker (image), Helm (déploiement du chart), Kubernetes (l'appli tourne). En dev local, `docker compose up` remplace les deux dernières étapes.

---

Q: Quelle est la différence entre Terraform et Ansible ?
R: Terraform provisionne (crée VM, réseau, cluster). Ansible configure l'intérieur des machines existantes (paquets, utilisateurs, services).

---

Q: Quelle est la différence entre Docker Compose et Kubernetes ?
R: Compose lance plusieurs conteneurs sur une seule machine (dev, petit serveur). Kubernetes les orchestre sur un cluster (prod, haute disponibilité, mise à l'échelle, redémarrages automatiques).

---

Q: Helm fonctionne-t-il avec Docker Compose ?
R: Non. Helm n'existe que dans l'univers Kubernetes : c'est un gestionnaire de paquets et de templates pour les manifestes k8s.

---

Q: Qu'est-ce qu'un chart Helm et qu'est-ce qu'une release ?
R: Un chart est un modèle paramétrable de manifestes k8s (`Chart.yaml`, `templates/`, `values.yaml`). Une release est une installation de ce chart dans un cluster, avec son historique de révisions.

---

Q: Que fait `helm template` ?
R: Il affiche les manifestes YAML générés à partir du chart et des values, sans rien déployer. Utile pour vérifier avant `helm install`.

---

Q: Comment revenir en arrière avec Helm ?
R: `helm rollback <release> <révision>` remet la release à une révision précédente de son historique.

---

Q: Quelle est la commande clé de chaque outil ?
R: `terraform apply`, `ansible-playbook`, `docker build` / `docker run`, `docker compose up`, `kubectl apply`, `helm install`.

---

Q: Quel fichier typique pour chaque outil ?
R: Terraform : `main.tf`. Ansible : `playbook.yml`. Docker : `Dockerfile`. Compose : `compose.yaml`. Kubernetes : manifestes YAML. Helm : `Chart.yaml` et `values.yaml`.

---

Q: Que signifie IaC ?
R: Infrastructure as Code : décrire l'infrastructure (machines, réseaux, services) dans des fichiers versionnés plutôt que de la créer à la main. Terraform en est l'exemple typique.

---

Q: Que signifie k8s ?
R: Abréviation de Kubernetes : « k », puis les 8 lettres « ubernete », puis « s ».

---

Q: Que signifie HCL ?
R: HashiCorp Configuration Language : le langage des fichiers `.tf` de Terraform.

---

Q: Que signifie VPC ?
R: Virtual Private Cloud : un réseau privé virtuel isolé chez un fournisseur cloud, dans lequel Terraform crée les machines.

---

Q: Que signifie YAML ?
R: YAML Ain't Markup Language : un format de données lisible, utilisé par Compose, les manifestes Kubernetes, les playbooks Ansible et `values.yaml` de Helm.

---

Q: Qu'est-ce que le state de Terraform ?
R: Le fichier d'état qui mémorise ce que Terraform a déjà créé. Il lui permet de calculer l'écart entre le code et la réalité lors de `terraform plan` et `terraform apply`.

---

Q: Que veut dire qu'un playbook Ansible est idempotent ?
R: Le relancer ne change rien si la machine est déjà dans l'état décrit. Ansible agit par SSH, sans agent installé sur les machines.

---

Q: Citez deux chevauchements entre ces outils.
R: Terraform a des providers `helm` et `kubernetes` : il peut créer le cluster puis y déployer des releases. Ansible peut appeler Docker, Compose ou `kubectl`, mais on l'utilise alors comme simple script.

---

Q: Quels outils sont déclaratifs, c'est-à-dire décrivent un état désiré ?
R: Terraform, Compose, Kubernetes et Helm. Ansible décrit aussi un état, avec des tâches idempotentes.

---

Q: Lequel de ces outils Orion utilise-t-il déjà, et où ?
R: Docker (`Dockerfile`), Compose (`deploy/compose/`), Helm (`deploy/helm/microcrm/`), Kubernetes (cluster kind jetable dans la CI) et Terraform (`deploy/terraform/`). Ansible n'est pas utilisé : aucune machine à configurer.

---

Q: Pourquoi le `Dockerfile` d'Orion a-t-il des étapes `front-dist` et `back-dist` ?
R: Elles ne contiennent que le produit compilé. À la main, il vient de l'étape de compilation ; en CI, `--build-context` les remplace par l'artefact du job de tests : l'image n'est pas recompilée.

---

Q: Comment la CI d'Orion déploie-t-elle l'application ?
R: Sur un cluster kind créé pour le run : Terraform prépare l'environnement et installe le chart Helm, pour dev, staging et production. Retour arrière par `helm rollback`.
