"""Correspondance entre les jobs de la CI et les scripts de scripts/ci/, et comportements de ces scripts.

La règle est écrite en tête de .github/workflows/ci.yml. Le workflow est lu comme du texte : la bibliothèque standard
n'a pas d'analyseur YAML.
"""

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
WORKFLOW = SCRIPTS.parent / ".github" / "workflows" / "ci.yml"
# Jobs liés à des services, des droits ou des résultats propres à GitHub : pas de script rejouable.
GITHUB_ONLY = {"sonar-front", "sonar-back", "sonar-infra", "candidate", "release", "notify"}
# Variables posées par la CI qui changeraient le comportement des scripts : ces tests tournent aussi dans la CI.
CI_VARIABLES = ("GITHUB_ACTIONS", "GITHUB_OUTPUT", "IMAGE_ARTIFACTS", "BASE", "PLANNED", "STAGING_CLUSTER")


def jobs():
    """Nom de chaque job du workflow, avec son texte."""
    body = WORKFLOW.read_text().split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([A-Za-z0-9_-]+):\n", body, flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def job_scripts():
    return {path.stem for path in (SCRIPTS / "ci").glob("*.sh")}


def calls_of(text):
    """Scripts de job lancés par un job, commentaires exclus."""
    code = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))
    return re.findall(r"scripts/ci/([A-Za-z0-9_-]+)\.sh", code)


class CorrespondenceTests(unittest.TestCase):
    def test_every_job_is_either_replayable_or_listed_as_github_only(self):
        self.assertEqual(set(jobs()) - GITHUB_ONLY, job_scripts())

    def test_each_job_runs_the_script_of_its_name_and_no_other(self):
        for name, text in jobs().items():
            with self.subTest(job=name):
                self.assertEqual(calls_of(text), [] if name in GITHUB_ONLY else [name])

    def test_ci_local_knows_every_replayable_job(self):
        source = (SCRIPTS / "ci_local.sh").read_text()
        everything = re.search(r"^all=\(([^)]*)\)$", source, flags=re.M).group(1).split()
        # `staging` demande un cluster : accepté, mais hors de `all`.
        self.assertEqual(sorted([*everything, "staging"]), sorted(job_scripts()))

    def test_job_scripts_are_executable_and_documented(self):
        for path in (SCRIPTS / "ci").glob("*.sh"):
            with self.subTest(script=path.name):
                self.assertTrue(os.access(path, os.X_OK))
                self.assertIn(f"job `{path.stem}`", path.read_text())


class JobScriptCase(unittest.TestCase):
    """Docker et curl sont remplacés par de faux programmes qui notent leurs appels : rien n'est lancé."""

    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.bin = Path(directory.name)
        self.log = self.bin / "calls.log"
        self.fake("docker")
        self.fake("curl")

    def fake(self, name, body=""):
        path = self.bin / name
        path.write_text(f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\n{body}\n')
        path.chmod(0o755)

    def run_job(self, name, **variables):
        env = {key: value for key, value in os.environ.items() if key not in CI_VARIABLES}
        env.update(
            PATH=f"{self.bin}{os.pathsep}{env['PATH']}", TRIVY_CACHE_DIR=str(self.bin / "trivy"),
            SMOKE_TIMEOUT="0", **variables,
        )
        return subprocess.run(
            [str(SCRIPTS / "ci" / f"{name}.sh")], env=env, capture_output=True, text=True, timeout=30
        )

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""


class ImagesJobTests(JobScriptCase):
    def test_the_ci_cannot_silently_recompile(self):
        result = self.run_job("images", GITHUB_ACTIONS="true")
        self.assertEqual(result.returncode, 1)
        self.assertIn("IMAGE_ARTIFACTS", result.stderr)
        self.assertEqual(self.calls(), "")

    def test_a_workstation_compiles_in_the_dockerfile(self):
        result = self.run_job("images")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--target back", self.calls())
        self.assertNotIn("--build-context", self.calls())


class ScanJobTests(JobScriptCase):
    def test_images_are_scanned_even_when_the_repository_scan_fails(self):
        self.fake("docker", 'case "$*" in *" fs "*"--exit-code"*) exit 1 ;; esac')
        result = self.run_job("scan")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("microcrm-back:ci", self.calls())


class ComposeJobTests(JobScriptCase):
    def test_a_failure_shows_the_logs_then_removes_only_the_ci_project(self):
        self.fake("curl", "exit 1")
        result = self.run_job("compose-test")
        self.assertNotEqual(result.returncode, 0)
        compose = [line for line in self.calls().splitlines() if line.startswith("docker compose")]
        self.assertTrue(all(" -p ci-dev " in line for line in compose), compose)
        self.assertTrue(compose[-2].endswith("logs --tail 100"), compose)
        self.assertTrue(compose[-1].endswith("down -v"), compose)


class StagingJobTests(JobScriptCase):
    def test_an_unknown_cluster_is_refused_before_any_action(self):
        result = self.run_job("staging", STAGING_CLUSTER="production")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.calls(), "")

    def test_the_planned_version_is_reported_even_when_the_deployment_fails(self):
        # Version prévue : rien n'est chargé dans le cluster. kubectl vise un autre contexte, le déploiement échoue.
        self.fake("kubectl", 'if [ "$1 $2" = "config current-context" ]; then echo elsewhere; fi')
        self.fake("kind")
        output = self.bin / "github-output"
        result = self.run_job(
            "staging", STAGING_CLUSTER="kind", PLANNED="true", PLANNED_VERSION="9.8.7",
            GITHUB_REPOSITORY="Owner/Repo", GITHUB_OUTPUT=str(output),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output.read_text(), "version=9.8.7\n")
        self.assertNotIn("kind load", self.calls())


if __name__ == "__main__":
    unittest.main()
