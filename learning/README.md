# learning — apprentissage et révisions autour d'Orion

Espace de révision construit à partir du projet : fiches de cours et flashcards. Il ne contient aucun
code de l'application et n'est lu par aucun build. Même organisation que les dossiers `learning/` des
projets DataShare (P3) et OlympicTracker (P4).

## Contenu

| Dossier | Rôle | Format |
|---|---|---|
| [`fiches/`](fiches/) | une fiche par sujet : le concept, un tableau comparatif, le lien avec le code du projet | Markdown (sources) ; images dans [`fiches/img/`](fiches/img/) |
| [`flashcards/`](flashcards/) | une série de cartes par sujet, pour la mémorisation | Markdown, cartes `Q:` / `R:` séparées par `---` |
| [`build/fiches/`](build/fiches/) | PDF des fiches, **générés** : ne pas les modifier à la main | PDF |
| [`build/flashcards/`](build/flashcards/) | CSV d'import Anki, **générés** : idem | CSV |

## Sujets

| Sujet | Fiche | Flashcards |
|---|---|---|
| **Le processus CI/CD d'Orion** (à lire en premier) | [fiche](fiches/processus-ci-cd.md) · [PDF](build/fiches/processus-ci-cd.pdf) | [cartes](flashcards/processus-ci-cd.md) · [CSV Anki](build/flashcards/processus-ci-cd.csv) |
| Les conteneurs : images et Compose | [fiche](fiches/conteneurs-orion.md) · [PDF](build/fiches/conteneurs-orion.pdf) | [cartes](flashcards/conteneurs-orion.md) · [CSV Anki](build/flashcards/conteneurs-orion.csv) |
| Kubernetes, Helm et Terraform | [fiche](fiches/kubernetes-helm-terraform-orion.md) · [PDF](build/fiches/kubernetes-helm-terraform-orion.pdf) | [cartes](flashcards/kubernetes-helm-terraform-orion.md) · [CSV Anki](build/flashcards/kubernetes-helm-terraform-orion.csv) |
| Qualité et sécurité dans le pipeline | [fiche](fiches/securite-qualite-orion.md) · [PDF](build/fiches/securite-qualite-orion.pdf) | [cartes](flashcards/securite-qualite-orion.md) · [CSV Anki](build/flashcards/securite-qualite-orion.csv) |
| Les tests | [fiche](fiches/tests-orion.md) · [PDF](build/fiches/tests-orion.pdf) | [cartes](flashcards/tests-orion.md) · [CSV Anki](build/flashcards/tests-orion.csv) |
| Pense-bête DevOps : Terraform, Ansible, Docker, Compose, Kubernetes, Helm | [fiche](fiches/pense-bete-devops-outils.md) · [PDF](build/fiches/pense-bete-devops-outils.pdf) | [cartes](flashcards/pense-bete-devops-outils.md) · [CSV Anki](build/flashcards/pense-bete-devops-outils.csv) |

## Conventions

- **Un sujet, un nom commun** : la fiche et les flashcards d'un même sujet portent le même nom
  (par exemple `pense-bete-devops-outils`).
- **Ancrage dans le projet** : chaque fiche a une section « Dans Orion » qui renvoie vers les fichiers
  réels (`Dockerfile`, `ci.yml`, docs du plan…), pour que le cours reste lié au code.
- **Markdown d'abord** : il se lit sur GitHub et se compare bien dans git. Les fiches `.md` sont les
  sources ; les fichiers de `build/` en dérivent.
- **Acronymes** : développés à la première occurrence dans la fiche, et une carte dédiée par sigle
  dans les flashcards.

## Génération des PDF et des CSV Anki

`learning/build.sh [source...]` produit les fichiers dans `build/fiches/` (PDF) et `build/flashcards/`
(CSV) ; sans argument, toutes les sources sont traitées :

- une fiche `.md` passe par `pandoc` et [`style.css`](style.css), puis Chrome, Chromium ou Edge en mode
  headless imprime le HTML en PDF (les images de `fiches/img/` sont intégrées) ;
- un fichier de flashcards devient un CSV par [`anki_csv.py`](anki_csv.py) (`python3`), deck
  `Orion::<sujet>`.

Prérequis : `pandoc`, `python3` et un navigateur Chrome, Chromium ou Edge.

## Régénération automatique au commit

Le hook [`.githooks/pre-commit`](../.githooks/pre-commit) régénère `build/` quand une source change dans
le commit (fiche, flashcards, image de `fiches/img/`, ou `build.sh`, `anki_csv.py`, `style.css`) et
ajoute les fichiers générés au commit. Activation, une fois par clone :

```bash
git config core.hooksPath .githooks
```
