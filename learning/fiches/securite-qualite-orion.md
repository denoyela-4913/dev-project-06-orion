# Qualité et sécurité dans le pipeline d'Orion

Le principe du **shift-left** : détecter le plus tôt possible, quand corriger coûte le moins.

## Qui détecte quoi

| Outil | Regarde | Trouve | Bloquant |
|---|---|---|---|
| ESLint | TypeScript, templates Angular | promesses non gérées, erreurs fréquentes, accessibilité de base | oui |
| hadolint | Dockerfile | paquets non épinglés, utilisateur non numérique | oui |
| Checkstyle | sources Java | style et conventions | oui |
| SpotBugs | classes Java **compilées** | défauts probables (objets internes exposés…) | oui |
| SonarQube Cloud | les trois parties | bugs, vulnérabilités, *hotspots*, duplication | non |
| `coverage_gate.py` | rapports de tests | couverture sous 80 % | oui |
| Trivy | dépendances, images, configurations | vulnérabilités connues, secrets, mauvais réglages | critique ou haute corrigeable |

**SAST** (*Static Application Security Testing*) analyse le code sans l'exécuter. Un scan de dépendances compare
les versions utilisées à une base de **CVE** (*Common Vulnerabilities and Exposures*, vulnérabilités publiées).

Checkstyle et SpotBugs s'exécutent dans `test-back` (`./gradlew check`). Sonar importe leurs rapports sans les
relancer : tous les résultats se lisent au même endroit, et Gradle reste le seul à bloquer.

## La couverture

Part des lignes et branches exécutées par les tests. Orion exige 80 % pour le front **et** pour le back, sur tout
le code **et** sur le code nouveau : quatre taux, pour qu'une partie n'en masque pas une autre.

> Une couverture élevée ne prouve pas que les tests vérifient quelque chose. D'où la règle : un correctif a un
> test qui **échoue sans lui**.

## La chaîne d'approvisionnement

| Risque | Parade dans Orion |
|---|---|
| un tag d'action ou d'image est déplacé | actions par SHA, images par digest |
| une dépendance change à notre insu | `package-lock.json`, `gradle.lockfile` strict, `.terraform.lock.hcl` |
| un script d'installation malveillant | `npm ci --ignore-scripts` |
| une version compromise vient de sortir | délai de 7 jours avant de l'adopter |
| un job compromis écrit dans le dépôt | droits d'écriture réservés aux jobs `release` et `notify` |

> **Cas réel.** En mars 2026, la chaîne de publication de **Trivy** a été compromise : des tags de ses actions
> GitHub ont été réécrits pour voler des secrets. Un pipeline qui référençait ces **tags** a exécuté le code
> malveillant ; une référence par **digest** ne peut pas être déplacée. Orion n'utilise que l'image officielle,
> par digest, dans un job sans secret.

## Ce qui manque encore

- L'API n'a **pas d'authentification** : quiconque l'atteint lit et modifie des données personnelles.
- `main` n'est pas protégée.
- Les Quality Gates Sonar ne bloquent pas.

## Dans Orion

[`docs/SECURITE.md`](../../docs/SECURITE.md), [`scripts/trivy.sh`](../../scripts/trivy.sh),
[`scripts/coverage_gate.py`](../../scripts/coverage_gate.py),
[`back/config/`](../../back/config/), [`front/eslint.config.js`](../../front/eslint.config.js).

## À retenir

1. Chaque outil a son angle : aucun ne remplace les autres.
2. Épingler par SHA ou digest protège d'un tag déplacé.
3. Un contrôle qui n'a jamais échoué n'est pas prouvé : on l'essaie sur un défaut connu.
