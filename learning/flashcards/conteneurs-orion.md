# Flashcards — Les conteneurs d'Orion

Fiche associée : [conteneurs-orion](../fiches/conteneurs-orion.md)

Q: Quelle différence entre une image et un conteneur ?
R: L'image est un modèle figé (fichiers et commande) ; le conteneur est une exécution de cette image.

---

Q: Qu'apporte un build multi-étapes ?
R: Les outils de compilation restent dans les étapes intermédiaires : images finales plus petites et moins exposées.

---

Q: Pourquoi épingler une image par digest ?
R: Un tag peut être déplacé par son auteur ; le digest désigne un contenu immuable.

---

Q: Pourquoi `USER 10001` plutôt que `USER app` ?
R: Kubernetes (`runAsNonRoot`) ne peut vérifier qu'un identifiant numérique.

---

Q: Pourquoi lire l'adresse de l'API au démarrage ?
R: Pour que la même image serve à tous les environnements, sans reconstruction.

---

Q: Que fait le proxy `/api` de Caddy ?
R: Il relaie les appels vers le back : le navigateur ne parle qu'au front et le back n'est pas publié.

---

Q: Que signifie CORS, et est-ce un contrôle d'accès ?
R: Cross-Origin Resource Sharing. Non : c'est une règle appliquée par les navigateurs ; un script ou `curl` n'est pas concerné.

---

Q: Différence entre sonde de vivacité et sonde de disponibilité ?
R: La vivacité décide s'il faut redémarrer le conteneur ; la disponibilité s'il peut recevoir du trafic.

---

Q: Pourquoi Actuator n'expose-t-il que `health` dans Orion ?
R: L'API n'a pas d'authentification : `env`, `heapdump` ou `beans` divulgueraient des informations internes.

---

Q: Comment Compose gère-t-il plusieurs environnements dans Orion ?
R: Un socle (`compose.yaml`) complété par des fichiers de surcharge, choisis par `scripts/compose.sh`, avec un nom de projet par environnement.

---

Q: Pourquoi un volume neuf peut-il être inaccessible à un conteneur non root ?
R: Si le dossier de montage n'existe pas dans l'image, le volume est créé au nom de root.

---

Q: Comment Caddy ouvre-t-il les ports 80 et 443 sans root ni capacité ?
R: Docker (20.10 et suivants) laisse un processus non root ouvrir ces ports dans un conteneur ; sur Kubernetes, Orion écoute sur 8080. Toutes les capacités sont retirées.
