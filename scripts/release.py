#!/usr/bin/env python3
"""Prochaine version SemVer et notes de release, d'après les commits conventionnels depuis le dernier tag.

Règles:
- changement incompatible (`type!:` ou pied de message `BREAKING CHANGE:`): version majeure; avant 1.0.0, la
  mineure (SemVer: en 0.y.z, tout peut changer);
- `feat`: version mineure;
- `fix`, `perf`, `build` (ce qui change le produit livré): correctif;
- le reste (docs, ci, test, chore, style, refactor): pas de release à lui seul.

Usage, à la racine du dépôt: release.py
La sortie standard reçoit `released=true|false`, puis `version=` et `tag=` (format de GITHUB_OUTPUT: la CI la
redirige vers ce fichier). Les notes sont écrites dans `release-notes.md`, dans le dossier courant.
Le script ne crée ni tag ni release: c'est le job `release` de la CI qui publie.
Bibliothèque standard seule.
"""
import argparse
import re
import subprocess
from typing import NamedTuple

TAG = re.compile(r'^v(\d+)\.(\d+)\.(\d+)$')
SUBJECT = re.compile(r'^(?P<kind>[a-z]+)(\((?P<scope>[^)]*)\))?(?P<breaking>!)?: (?P<text>.+)$')
NOTES_FILE = 'release-notes.md'
PATCH_KINDS = {'fix', 'perf', 'build'}
SECTIONS = (('breaking', 'Changements incompatibles'), ('feat', 'Nouveautés'), ('fix', 'Corrections'),
            ('other', 'Autres changements'))


class Commit(NamedTuple):
    sha: str
    subject: str
    body: str


def is_breaking(commit):
    match = SUBJECT.match(commit.subject)
    return bool(match and match['breaking']) or re.search(r'^BREAKING[ -]CHANGE: ', commit.body, re.M) is not None


def kind_of(commit):
    match = SUBJECT.match(commit.subject)
    return match['kind'] if match else None


def last_version(tags):
    versions = [tuple(int(part) for part in match.groups()) for match in map(TAG.match, tags) if match]
    return max(versions, default=(0, 0, 0))


def next_version(current, commits):
    """Version suivante, ou None si aucun commit ne justifie une release."""
    major, minor, patch = current
    if any(map(is_breaking, commits)):
        return (major + 1, 0, 0) if major else (0, minor + 1, 0)
    kinds = {kind_of(commit) for commit in commits}
    if 'feat' in kinds:
        return (major, minor + 1, 0)
    if kinds & PATCH_KINDS:
        return (major, minor, patch + 1)
    return None


def text(version):
    return '.'.join(map(str, version))


def notes(version, commits):
    groups = {key: [] for key, _ in SECTIONS}
    for commit in commits:
        match = SUBJECT.match(commit.subject)
        kind = kind_of(commit)
        key = 'breaking' if is_breaking(commit) else 'feat' if kind == 'feat' else 'fix' if kind == 'fix' else 'other'
        if key == 'other':
            label = commit.subject
        else:
            label = (f"**{match['scope']}**: " if match['scope'] else '') + match['text']
        groups[key].append(f'- {label} ({commit.sha})')
    parts = [f'## v{text(version)}']
    for key, title in SECTIONS:
        if groups[key]:
            parts.append(f'### {title}\n\n' + '\n'.join(groups[key]))
    return '\n\n'.join(parts) + '\n'


def git(repository, *arguments):
    return subprocess.run(['git', *arguments], cwd=repository, check=True, capture_output=True, text=True).stdout


def plan(repository):
    """(version à publier ou None, commits depuis le dernier tag de version présent dans l'historique)."""
    current = last_version(git(repository, 'tag', '--merged', 'HEAD').split())
    span = f'v{text(current)}..HEAD' if current != (0, 0, 0) else 'HEAD'
    # \x1f entre les champs, \x1e entre les commits: absents des messages.
    log = git(repository, 'log', '--no-merges', '--format=%h%x1f%s%x1f%b%x1e', span, '--')
    commits = [Commit(*record.strip('\n').split('\x1f')) for record in log.split('\x1e') if record.strip()]
    return next_version(current, commits), commits


def main(argv=None):
    # Aucune option: tout chemin est fixe, rien venant de la ligne de commande n'est ouvert (Sonar S8707).
    argparse.ArgumentParser(description=__doc__.splitlines()[0]).parse_args(argv)

    version, commits = plan('.')
    if version is None:
        print('released=false')
    else:
        with open(NOTES_FILE, 'w', encoding='utf-8') as file:
            file.write(notes(version, commits))
        print(f'released=true\nversion={text(version)}\ntag=v{text(version)}')


if __name__ == '__main__':
    main()
