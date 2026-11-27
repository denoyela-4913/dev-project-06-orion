# Flashcards — Les tests d'Orion

Fiche associée : [tests-orion](../fiches/tests-orion.md)

Q: Que décrit la pyramide des tests ?
R: Beaucoup de tests unitaires rapides, moins de tests d'intégration et fonctionnels, peu de tests de bout en bout, lents et fragiles.

---

Q: Différence entre test fonctionnel d'API et test unitaire ?
R: Le test fonctionnel suit un scénario complet par HTTP sur l'application démarrée ; le test unitaire vérifie une unité isolée.

---

Q: Que signifie e2e ?
R: End to end : de bout en bout, l'application assemblée pilotée comme par un utilisateur.

---

Q: Qu'est-ce qu'un smoke test ?
R: Une vérification courte qu'une instance déployée fonctionne pour l'essentiel.

---

Q: Pourquoi voir un test échouer avant de corriger ?
R: Pour prouver qu'il détecte bien le défaut.

---

Q: Pourquoi refuser les nouveaux essais automatiques ?
R: Ils masquent une instabilité, qui est un défaut du test ou de l'application.

---

Q: Quel outil pilote le navigateur dans les tests e2e d'Orion ?
R: Playwright, avec Chromium, dans l'image officielle épinglée par digest.

---

Q: Les tests e2e comptent-ils dans la couverture d'Orion ?
R: Non : la couverture vient des tests unitaires et fonctionnels.

---

Q: Pourquoi tester la restauration d'une sauvegarde ?
R: Une sauvegarde qu'on n'a jamais restaurée peut être inutilisable sans qu'on le sache.
