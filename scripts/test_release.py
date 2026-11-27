"""Tests de release.py. Lancement: python3 -m unittest discover -s scripts"""
import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path

import release


def commit(subject, body=''):
    return release.Commit('abc1234', subject, body)


class BumpTest(unittest.TestCase):
    def test_a_feature_raises_the_minor_version(self):
        self.assertEqual((0, 1, 0), release.next_version((0, 0, 2), [commit('fix: a'), commit('feat(front): b')]))

    def test_a_fix_raises_the_patch_version(self):
        for kind in ('fix', 'perf', 'build'):
            self.assertEqual((1, 2, 4), release.next_version((1, 2, 3), [commit(f'{kind}: a'), commit('docs: b')]))

    def test_commits_without_effect_on_the_product_make_no_release(self):
        commits = [commit(f'{kind}: a') for kind in ('docs', 'ci', 'test', 'chore', 'style', 'refactor')]

        self.assertIsNone(release.next_version((1, 2, 3), commits + [commit('message libre')]))

    def test_a_breaking_change_raises_the_major_version_after_1_0_0(self):
        self.assertEqual((2, 0, 0), release.next_version((1, 2, 3), [commit('refactor!: a')]))
        self.assertEqual((2, 0, 0), release.next_version((1, 2, 3), [commit('fix: a', 'BREAKING CHANGE: api')]))

    def test_before_1_0_0_a_breaking_change_raises_the_minor_version(self):
        self.assertEqual((0, 4, 0), release.next_version((0, 3, 1), [commit('feat!: a')]))


class VersionTest(unittest.TestCase):
    def test_the_highest_semver_tag_is_the_last_version(self):
        self.assertEqual((0, 10, 0), release.last_version(['v0.9.1', 'v0.10.0', 'v0.2.0']))

    def test_other_tags_are_ignored(self):
        self.assertEqual((0, 0, 1), release.last_version(['v0.0.1', 'v9', 'v1.0.0-rc.1', 'demo']))

    def test_without_any_version_tag_the_count_starts_at_0_0_0(self):
        self.assertEqual((0, 0, 0), release.last_version([]))


class NotesTest(unittest.TestCase):
    def test_notes_group_the_commits_by_kind(self):
        notes = release.notes((0, 1, 0), [
            commit('feat: export'), commit('fix(back): cors'), commit('docs: readme'), commit('feat!: new api')])

        self.assertIn('## v0.1.0', notes)
        self.assertLess(notes.index('### Changements incompatibles'), notes.index('### Nouveautés'))
        self.assertIn('- new api (abc1234)', notes)
        self.assertIn('- export (abc1234)', notes)
        self.assertIn('- **back**: cors (abc1234)', notes)
        self.assertIn('### Autres changements', notes)
        self.assertIn('- docs: readme (abc1234)', notes)


class GitTest(unittest.TestCase):
    """Lecture d'un vrai dépôt temporaire."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git('init', '-q', '-b', 'main')

    def git(self, *arguments):
        subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@example.net', *arguments],
                       cwd=self.root, check=True, capture_output=True)

    def add(self, message):
        self.git('commit', '-q', '--allow-empty', '-m', message)

    def test_plan_covers_only_the_commits_after_the_last_tag(self):
        self.add('feat: old')
        self.git('tag', 'v0.1.0')
        self.add('fix: new\n\ndetails')

        version, commits = release.plan(self.root)

        self.assertEqual((0, 1, 1), version)
        self.assertEqual(['fix: new'], [c.subject for c in commits])
        self.assertEqual('details', commits[0].body.strip())

    def test_nothing_to_release_right_after_a_tag(self):
        self.add('feat: old')
        self.git('tag', 'v0.1.0')

        self.assertEqual((None, []), release.plan(self.root))

    def run_main(self):
        output = io.StringIO()
        with contextlib.chdir(self.root), contextlib.redirect_stdout(output):
            code = release.main([])
        return code, output.getvalue()

    # Aucun chemin ne vient de la ligne de commande (Sonar S8707): les sorties vont sur la sortie standard, que la
    # CI redirige vers GITHUB_OUTPUT, et les notes dans un fichier au nom fixe.
    def test_main_prints_the_outputs_and_writes_the_notes(self):
        self.add('feat: first')

        code, output = self.run_main()

        self.assertEqual(0, code)
        self.assertEqual('released=true\nversion=0.1.0\ntag=v0.1.0\n', output)
        self.assertIn('- first', (self.root / 'release-notes.md').read_text())

    def test_main_reports_that_there_is_nothing_to_release(self):
        self.add('docs: only')

        code, output = self.run_main()

        self.assertEqual((0, 'released=false\n'), (code, output))
        self.assertFalse((self.root / 'release-notes.md').exists())

    def test_main_accepts_no_path_argument(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            release.main(['--notes', '/tmp/elsewhere.md'])


if __name__ == '__main__':
    unittest.main()
