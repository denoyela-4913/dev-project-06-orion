# Les conteneurs d'Orion : images, Compose

Une **image** est un système de fichiers figé avec la commande à lancer ; un **conteneur** en est une exécution.
**Docker Compose** décrit plusieurs conteneurs qui fonctionnent ensemble sur une machine.

## Un Dockerfile, deux images

| Cible | Base | Contenu | Rôle |
|---|---|---|---|
| `front` | Alpine | Caddy et le front compilé | déploiement |
| `back` | Alpine | JRE (*Java Runtime Environment*) et le JAR | déploiement |

Les étapes `front-dist` et `back-dist` ne contiennent que le produit compilé : en CI, il vient de l'artefact du job de
tests (`docker build --build-context`), sinon de l'étape de compilation.

Les étapes `front-build` (Node) et `back-build` (Gradle) compilent ; leurs outils ne sont pas dans les images
finales : c'est le **build multi-étapes** (images plus petites, moins de surface d'attaque).

## Rendre une image sûre

| Règle | Pourquoi |
|---|---|
| base épinglée par **digest** (`@sha256:…`) | un tag peut être déplacé, un digest non |
| utilisateur **non root numérique** (`USER 10001`) | limite les dégâts ; Kubernetes ne vérifie `runAsNonRoot` qu'avec un nombre |
| paquets épinglés à la mineure (`caddy=~2.11`) | garde les correctifs, bloque les changements de version |
| rien de secret dans l'image | tout ce qui y entre peut être relu |

## Une image, tous les environnements

Le front ne connaît pas l'adresse de l'API à la compilation : Caddy sert `/config.js`, construit depuis la
variable `API_BASE_URL`. La même image sert en dev, staging et production.

```
navigateur ──▶ front (Caddy) ──/api──▶ back (Spring Boot)
                  └── fichiers du front
```

Avec `/api`, le navigateur ne parle qu'au front : le back n'a pas besoin d'être publié.

> **CORS** (*Cross-Origin Resource Sharing*) est la règle par laquelle un serveur autorise une page d'une **autre
> origine** à lire ses réponses. Ce n'est **pas** un contrôle d'accès : `curl` l'ignore.

## Les sondes de santé

| Sonde | Question | Chemin |
|---|---|---|
| vivacité (*liveness*) | le processus est-il bloqué ? | `/actuator/health/liveness` |
| disponibilité (*readiness*) | peut-il recevoir du trafic ? | `/actuator/health/readiness` |
| front | Caddy répond-il ? | `/healthz` |

## Compose : un socle et des surcharges

| Fichier | Contenu |
|---|---|
| `compose.yaml` | les deux services, leurs sondes, l'ordre de démarrage |
| `compose.dev.yaml` | ports locaux, back publié |
| `compose.hardened.yaml` | staging **et** production : lecture seule, droits retirés, mémoire limitée, volume de données, HTTPS |
| `env/<environnement>.env` | les seules valeurs propres à une installation : domaine, origine publique, ports |

```bash
scripts/compose.sh staging up -d --build --wait
SMOKE_INSECURE=1 scripts/smoke_test.sh https://localhost:4443
```

> **Piège vécu.** Un volume neuf monté sur un dossier **absent de l'image** appartient à root : Caddy, non root,
> ne pouvait pas y écrire. Solution : créer le dossier dans le Dockerfile avec le bon propriétaire.

> **Piège vécu.** Derrière le proxy, le back refusait des écritures de la **même origine** (403) dès que l'adresse
> différait de celle configurée. Caddy retire désormais `Origin` seulement quand il désigne l'adresse de la requête.

## Dans Orion

[`Dockerfile`](../../Dockerfile), [`misc/docker/Caddyfile`](../../misc/docker/Caddyfile),
[`deploy/compose/`](../../deploy/compose/), [`scripts/compose.sh`](../../scripts/compose.sh),
[`scripts/smoke_test.sh`](../../scripts/smoke_test.sh).

## À retenir

1. Build multi-étapes, digest, utilisateur numérique non root.
2. La configuration vient de l'environnement, pas de l'image.
3. Une sonde de santé n'est pas un test : le *smoke test* vérifie un vrai parcours.
