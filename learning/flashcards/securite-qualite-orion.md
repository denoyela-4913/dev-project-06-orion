# Flashcards — Qualité et sécurité dans Orion

Fiche associée : [securite-qualite-orion](../fiches/securite-qualite-orion.md)

Q: Que signifie « shift-left » ?
R: Déplacer les contrôles vers le début du cycle, là où corriger coûte le moins.

---

Q: Pourquoi SpotBugs ne va-t-il pas dans le job de lint ?
R: Il analyse les classes compilées ; il s'exécute avec `./gradlew check`, dans le job `test-back`.

---

Q: Que signifie SAST ?
R: Static Application Security Testing : analyser le code sans l'exécuter.

---

Q: Que signifie CVE ?
R: Common Vulnerabilities and Exposures : l'identifiant d'une vulnérabilité publiée.

---

Q: Quels seuils de couverture Orion impose-t-il ?
R: 80 % pour le front et pour le back, sur tout le code et sur le code nouveau, en mode bloquant.

---

Q: Pourquoi une couverture élevée ne suffit-elle pas ?
R: Elle mesure ce qui est exécuté, pas ce qui est vérifié.

---

Q: Quand le job de scan Trivy échoue-t-il ?
R: Sur une vulnérabilité critique ou haute qui a un correctif, un secret ou une erreur de configuration grave.

---

Q: Pourquoi rescanner chaque semaine ?
R: De nouvelles vulnérabilités sont publiées sans qu'aucun commit ne relance la CI.

---

Q: Que s'est-il passé avec Trivy en mars 2026 ?
R: Sa chaîne de publication a été compromise : des tags de ses actions GitHub ont été réécrits pour voler des secrets de pipelines.

---

Q: Pourquoi référencer une action par SHA ?
R: Un SHA de commit est immuable ; un tag peut être déplacé vers un autre code.

---

Q: Que protège `npm ci --ignore-scripts` ?
R: Les scripts d'installation des dépendances ne s'exécutent pas.

---

Q: Quel est le principal risque de sécurité encore ouvert dans Orion ?
R: L'API n'a pas d'authentification.
