# Flashcards — Kubernetes, Helm et Terraform dans Orion

Fiche associée : [kubernetes-helm-terraform-orion](../fiches/kubernetes-helm-terraform-orion.md)

Q: Que fait un Deployment ?
R: Il maintient un nombre de pods identiques et gère leurs mises à jour progressives et leur historique.

---

Q: À quoi sert un Service ?
R: Il donne une adresse stable à un ensemble de pods qui changent.

---

Q: Que signifie PVC, et qu'apporte-t-il ?
R: PersistentVolumeClaim : une demande de stockage qui survit aux pods.

---

Q: Que fait une NetworkPolicy dans le chart d'Orion ?
R: Elle n'autorise que les pods du front à joindre le back (si le réseau du cluster l'applique).

---

Q: Qu'impose le niveau « restricted » des Pod Security Standards ?
R: Pas de root, pas d'élévation de privilèges, capacités retirées (seule NET_BIND_SERVICE peut être ajoutée), seccomp activé.

---

Q: Pourquoi le back d'Orion n'a-t-il qu'une instance ?
R: Sa base HSQLDB est interne au processus : plusieurs instances auraient des données différentes.

---

Q: Quand utiliser la stratégie `Recreate` ?
R: Quand l'ancienne et la nouvelle version ne peuvent pas tourner ensemble, par exemple un volume à un seul écrivain.

---

Q: Que fait `--atomic` (Helm 3), renommé `--rollback-on-failure` (Helm 4) ?
R: Si la mise à jour échoue (pods non prêts à temps), Helm revient à la révision précédente.

---

Q: Qu'est-ce que l'état (state) de Terraform ?
R: La liste de ce que Terraform a créé et de ses attributs ; il peut contenir des valeurs sensibles et ne se versionne pas.

---

Q: Pourquoi un dossier Terraform par environnement ?
R: Chacun a son état : une opération sur dev ne peut pas modifier la production.

---

Q: Comment tester un module Terraform sans cluster ?
R: `terraform test` avec un `mock_provider`.

---

Q: Un retour arrière Helm restaure-t-il les données ?
R: Non, seulement les manifestes. Les données se restaurent depuis une sauvegarde.

---

Q: Pourquoi une sauvegarde « à froid » ?
R: Copier les fichiers d'une base en cours d'écriture ne garantit pas leur cohérence.
