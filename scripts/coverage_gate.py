#!/usr/bin/env python3
"""Seuils de couverture par partie (front et back), sur tout le code et sur le code nouveau.

Même formule que SonarQube: (lignes + branches couvertes) / (lignes + branches à couvrir).
- tout le code: toutes les sources TypeScript (front) et Java (back);
- code nouveau: les seules lignes ajoutées ou modifiées par rapport à la base donnée (--base).

Non bloquant par défaut: les taux sous le seuil sont signalés, le code de sortie reste 0. Avec --blocking,
il vaut 1. Un rapport manquant ou vide fait toujours échouer: ce n'est pas un problème de taux.

Bibliothèque standard seule: aucune dépendance à installer ni à épingler dans la CI.
"""
import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

FRONT_REPORT = 'front/coverage/microcrm/lcov.info'
BACK_REPORT = 'back/build/reports/jacoco/test/jacocoTestReport.xml'

# Un rapport est un dictionnaire {fichier: {numéro de ligne: [couverts, à couvrir]}}; une ligne compte pour 1,
# plus 1 par branche.


def read_lcov(text, prefix):
    """Lit un lcov. Seuls les fichiers .ts comptent, comme dans Sonar (les templates HTML sont ignorés)."""
    report, lines = {}, None
    for record in text.splitlines():
        key, _, value = record.partition(':')
        if key == 'SF':
            lines = report.setdefault(prefix + value, {}) if value.endswith('.ts') else None
        elif lines is not None and key == 'DA':
            number, hits = value.split(',')[:2]
            line = lines.setdefault(int(number), [0, 0])
            line[0] += int(hits) > 0
            line[1] += 1
        elif lines is not None and key == 'BRDA':
            number, _, _, taken = value.split(',')
            line = lines.setdefault(int(number), [0, 0])
            line[0] += taken not in ('0', '-')
            line[1] += 1
    return report


def read_jacoco(text, prefix):
    report = {}
    for package in ElementTree.fromstring(text).iter('package'):
        for source in package.findall('sourcefile'):
            lines = report.setdefault(f"{prefix}{package.get('name')}/{source.get('name')}", {})
            for line in source.findall('line'):
                covered, missed = int(line.get('cb')), int(line.get('mb'))
                lines[int(line.get('nr'))] = [(int(line.get('ci')) > 0) + covered, 1 + covered + missed]
    return report


def added_lines(diff):
    """Numéros des lignes ajoutées ou modifiées, par fichier, d'après un `git diff --unified=0`."""
    result, path, in_header = {}, None, False
    for line in diff.splitlines():
        if line.startswith('diff --git '):
            path, in_header = None, True
        elif in_header and line.startswith('+++ '):
            path = line[len('+++ b/'):] if line.startswith('+++ b/') else None
        elif line.startswith('@@'):
            in_header = False
            match = re.match(r'@@ -\S+ \+(\d+)(?:,(\d+))? @@', line)
            start, count = int(match.group(1)), int(match.group(2) or 1)
            if path and count:
                result.setdefault(path, set()).update(range(start, start + count))
    return result


def git(*arguments, cwd=None):
    return subprocess.run(['git', *arguments], cwd=cwd, check=True, capture_output=True, text=True).stdout


def resolve_commit(reference, cwd=None):
    """Empreinte du commit désigné. `--end-of-options`: une valeur commençant par « - » n'est pas lue comme une
    option de git (Sonar S8705)."""
    commit = git('rev-parse', '--verify', '--end-of-options', f'{reference}^{{commit}}', cwd=cwd).strip()
    if not re.fullmatch(r'[0-9a-f]{40,64}', commit):
        raise ValueError(f'Référence git inattendue: {reference!r}')
    return commit


def read_diff(base, cwd=None):
    # `base...HEAD`: depuis l'ancêtre commun, sans les changements arrivés depuis sur la base. Seule l'empreinte,
    # vérifiée, est transmise à `git diff`, jamais la valeur reçue.
    commit = resolve_commit(base, cwd=cwd)
    return git('-c', 'core.quotepath=off', 'diff', '--unified=0', '--no-color', '--no-ext-diff',
               '--src-prefix=a/', '--dst-prefix=b/', f'{commit}...HEAD', cwd=cwd)


def totals(report, only=None):
    """(couverts, à couvrir), sur tout le rapport ou sur les seules lignes de `only`."""
    covered = total = 0
    for path, lines in report.items():
        for number, (line_covered, line_total) in lines.items():
            if only is None or number in only.get(path, ()):
                covered += line_covered
                total += line_total
    return covered, total


def rate(counts):
    covered, total = counts
    return 100 * covered / total if total else None


def failures(results, threshold):
    """Taux sous le seuil. « Rien à couvrir » n'est pas un échec."""
    return [(part, scope, rate(counts)) for part, scope, counts in results
            if counts[1] and counts[0] * 100 < threshold * counts[1]]


def both_parts_reached(results, threshold):
    """Vrai quand le front ET le back atteignent le seuil sur tout leur code."""
    return not failures([result for result in results if result[1] == 'global'], threshold)


def exit_code(results, threshold, blocking):
    return 1 if blocking and failures(results, threshold) else 0


def table(results, threshold):
    rows = ['| Partie | Périmètre | Taux | Couverts | Seuil | État |', '|---|---|---|---|---|---|']
    below = {(part, scope) for part, scope, _ in failures(results, threshold)}
    for part, scope, (covered, total) in results:
        if total:
            # Taux tronqué, pour ne pas afficher 80,0 % quand le seuil n'est pas atteint.
            value = f'{int(1000 * covered / total) / 10:.1f} %'
            state = 'sous le seuil' if (part, scope) in below else 'atteint'
        else:
            value, state = '-', 'rien à couvrir'
        rows.append(f'| {part} | {scope} | {value} | {covered}/{total} | {threshold} % | {state} |')
    return '\n'.join(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--base', help='référence git de comparaison pour le code nouveau')
    parser.add_argument('--threshold', type=int, default=80)
    parser.add_argument('--blocking', action='store_true', help='échouer si un taux est sous le seuil')
    args = parser.parse_args(argv)

    reports = {
        'front': read_lcov(Path(FRONT_REPORT).read_text(), 'front/'),
        'back': read_jacoco(Path(BACK_REPORT).read_text(), 'back/src/main/java/'),
    }
    new = None
    if args.base:
        new = added_lines(read_diff(args.base))

    results = []
    for part, report in reports.items():
        if not totals(report)[1]:
            sys.exit(f'Rapport de couverture vide pour le {part}.')
        results.append((part, 'global', totals(report)))
        if new is not None:
            results.append((part, 'nouveau code', totals(report, new)))

    mode = 'bloquant' if args.blocking else 'non bloquant'
    summary = f'## Seuils de couverture ({mode})\n\n{table(results, args.threshold)}\n'
    print(summary)
    if 'GITHUB_STEP_SUMMARY' in os.environ:
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
            output.write(summary)

    level = 'error' if args.blocking else 'warning'
    for part, scope, value in failures(results, args.threshold):
        print(f'::{level}::Couverture {part} ({scope}) sous {args.threshold} %: {int(value * 10) / 10:.1f} %')
    if not args.blocking and both_parts_reached(results, args.threshold):
        print(f'::warning::Front et back atteignent {args.threshold} %: passer COVERAGE_BLOCKING à "true" '
              'dans .github/workflows/ci.yml.')
    return exit_code(results, args.threshold, args.blocking)


if __name__ == '__main__':
    sys.exit(main())
