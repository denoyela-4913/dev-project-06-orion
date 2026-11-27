# Flashcards — Le processus CI/CD d'Orion

Fiche associée : [processus-ci-cd](../fiches/processus-ci-cd.md)

Q: Que signifie CI, et que fait-elle ?
R: Continuous Integration (intégration continue) : vérifier automatiquement chaque changement dès qu'il est poussé.

---

Q: Que signifie CD ?
R: Continuous Delivery (livraison continue : toujours prêt à publier) ou Continuous Deployment (déploiement continu : chaque changement validé est déployé).

---

Q: Quelles sont les sept étapes du pipeline d'Orion ?
R: lint, test et couverture, qualité (Sonar et seuils), build (applications, images, Compose), bout en bout et scan (Playwright, Trivy), release (sur `main`), déploiement de démonstration (PR et `main`).

---

Q: Pourquoi placer le lint en premier ?
R: C'est le contrôle le moins cher : échouer tôt évite de lancer des étapes longues. En contrepartie, chaque run réussi attend sa durée.

---

Q: Dans GitHub Actions, qu'est-ce qui crée l'ordre des jobs ?
R: `needs`. Il n'y a pas de notion de stage.

---

Q: Pourquoi écrire `!cancelled()` dans un `if` de job ?
R: Si un job de `needs` est sauté, GitHub saute les suivants. `!cancelled()` lève ce comportement ; il faut alors tester chaque `needs.<job>.result`.

---

Q: À quoi servent les artefacts entre jobs ?
R: Chaque job a sa propre machine : les artefacts transmettent rapports de couverture et images construites.

---

Q: Pourquoi publier l'image testée plutôt que la reconstruire ?
R: Une reconstruction peut différer (dépendances, base) : ce qui est publié ne serait plus ce qui a été testé et scanné.

---

Q: Quelles conditions pour qu'Orion publie une version ?
R: Un push sur `main`, tous les contrôles réussis (build, images, Compose, e2e, scan, infrastructure) et au moins un commit `feat`, `fix`, `perf`, `build` ou incompatible depuis le dernier tag.

---

Q: Quel commit donne une version mineure ? un correctif ?
R: `feat` : mineure. `fix`, `perf`, `build` : correctif.

---

Q: Que fait un changement incompatible avant la version 1.0.0 dans Orion ?
R: Il augmente la version mineure : en 0.y.z, SemVer autorise tout changement.

---

Q: Pourquoi le tag est-il créé après l'envoi des images ?
R: Pour qu'un tag désigne toujours une version complète.

---

Q: Pourquoi une release à la fois (`concurrency`) ?
R: Deux runs rapprochés calculeraient le même numéro de version.

---

Q: Que fait le job `deploy-demo` ?
R: Sur un cluster kind jetable : déploiement de dev, staging et production avec Terraform et Helm, test de santé, et épreuve des secours sur staging.

---

Q: Quelle est la limite du déploiement de démonstration d'Orion ?
R: Le cluster est jetable : pas d'environnement permanent, ni domaine ni certificat public. L'hébergement reste à décider.

---

Q: Quels sont les quatre indicateurs DORA ?
R: Fréquence de déploiement, délai de livraison (lead time), taux d'échec des changements, temps de rétablissement.

---

Q: Pourquoi fusionner en rebase ?
R: Pour garder un historique linéaire, lisible, dont la release calcule la version et les notes.
