"""Tests des garde-fous des scripts de lancement, de déploiement et de CI locale.

Les outils (kubectl, helm, minikube, docker, npm) sont remplacés par de faux programmes qui notent leurs appels :
rien n'est installé ni modifié.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent


class ScriptCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.bin = Path(directory.name)
        self.log = self.bin / "calls.log"
        for tool in ("minikube", "docker", "npm"):
            self.fake(tool)
        self.fake("kubectl", 'if [ "$1 $2" = "config current-context" ]; then echo minikube; fi')
        self.fake("helm")

    def fake(self, name, body=""):
        path = self.bin / name
        path.write_text(f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\n{body}\n')
        path.chmod(0o755)

    def run_script(self, *command):
        env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}")
        return subprocess.run(
            [str(SCRIPTS / command[0]), *command[1:]], env=env, capture_output=True, text=True, timeout=30
        )

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""


class UsageTests(ScriptCase):
    def test_bad_arguments_are_refused_before_any_action(self):
        for command in (
            ("app.sh",),
            ("app.sh", "start", "production"),
            ("helm-deploy.sh", "install"),
            ("helm-deploy.sh", "install", "production"),
            ("helm-deploy.sh", "delete", "dev"),
            ("ci_local.sh",),
            ("ci_local.sh", "lint", "unknown"),
            ("deps.sh", "remove"),
            ("deps.sh", "install", "database"),
        ):
            with self.subTest(command=command):
                result = self.run_script(*command)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("Usage", result.stderr)
                self.assertEqual(self.calls(), "")


class HelmDeployTests(ScriptCase):
    def test_another_cluster_is_never_touched(self):
        self.fake("kubectl", "echo production-cluster")
        result = self.run_script("helm-deploy.sh", "uninstall", "staging")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("minikube", result.stderr)
        self.assertNotIn("helm", self.calls())

    def test_install_refuses_an_existing_release(self):
        result = self.run_script("install-dev.sh")
        self.assertEqual(result.returncode, 1)
        self.assertIn("upgrade", result.stderr)
        self.assertNotIn("docker build", self.calls())

    def test_upgrade_requires_an_existing_release(self):
        self.fake("helm", "exit 1")
        result = self.run_script("upgrade-staging.sh")
        self.assertEqual(result.returncode, 1)
        self.assertIn("install", result.stderr)
        self.assertNotIn("docker build", self.calls())


class CiLocalTests(ScriptCase):
    def test_images_alone_never_reuse_old_artifacts(self):
        # Sans `test` dans la même commande, des artefacts peuvent dater d'un code ancien : le Dockerfile compile.
        result = self.run_script("ci_local.sh", "images")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--target back", self.calls())
        self.assertNotIn("--build-context", self.calls())

    def test_missing_tools_are_reported_before_any_step(self):
        # PATH réduit aux faux outils et au strict nécessaire pour lancer le script : terraform est absent.
        for tool in ("bash", "env", "dirname"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        result = subprocess.run(
            [str(SCRIPTS / "ci_local.sh"), "lint", "infra"], env=dict(os.environ, PATH=str(self.bin)),
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("terraform", result.stderr)
        self.assertEqual(self.calls(), "")


class DepsTests(ScriptCase):
    def test_front_install_uses_the_lockfile_without_package_scripts(self):
        result = self.run_script("deps.sh", "install", "front")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), "npm ci --ignore-scripts\n")

    def test_a_failed_install_fails_the_script(self):
        self.fake("npm", "exit 7")
        self.assertEqual(self.run_script("deps.sh", "install", "front").returncode, 7)

    def test_outdated_packages_are_not_an_error(self):
        self.fake("npm", "exit 1")
        self.assertEqual(self.run_script("deps.sh", "outdated", "front").returncode, 0)


if __name__ == "__main__":
    unittest.main()
