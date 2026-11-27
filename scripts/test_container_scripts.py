"""Tests des garde-fous des scripts de tests en conteneur et de construction des images.

Docker et curl sont remplacés par de faux programmes qui notent leurs appels : rien n'est construit ni lancé.
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent

# `container inspect <nom>` échoue (aucun conteneur), le reste réussit.
NO_CONTAINER = 'if [ "$1 $2" = "container inspect" ]; then exit 1; fi'


class ScriptCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.bin = Path(directory.name)
        self.log = self.bin / "calls.log"
        self.fake("docker", NO_CONTAINER)
        self.fake("curl")

    def fake(self, name, body=""):
        path = self.bin / name
        path.write_text(f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\n{body}\n')
        path.chmod(0o755)

    def run_script(self, *command):
        env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}", RUN_TIMEOUT="0")
        return subprocess.run(
            [str(SCRIPTS / command[0]), *command[1:]], env=env, capture_output=True, text=True, timeout=30
        )

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""


class UsageTests(ScriptCase):
    def test_bad_arguments_are_refused_before_any_action(self):
        for command in (("ci_test.sh",), ("ci_test.sh", "database")):
            with self.subTest(command=command):
                result = self.run_script(*command)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.calls(), "")


class BuildImagesTests(ScriptCase):
    def artifacts(self):
        directory = self.bin / "artifacts"
        for name in ("front/index.html", "back/microcrm-0.0.1-SNAPSHOT.jar"):
            (directory / name).parent.mkdir(parents=True)
            (directory / name).write_text("x")
        return str(directory)

    def test_missing_artifacts_stop_before_any_build(self):
        empty = self.bin / "empty"
        empty.mkdir()
        self.assertEqual(self.run_script("build_images.sh", str(empty)).returncode, 1)
        self.assertEqual(self.calls(), "")

    def test_artifacts_replace_the_dist_stages(self):
        directory = self.artifacts()
        result = self.run_script("build_images.sh", directory)
        self.assertEqual(result.returncode, 0, result.stderr)
        for part in ("front", "back"):
            self.assertIn(f"--build-context {part}-dist={directory}/{part}", self.calls())

    def test_a_compilation_despite_the_artifacts_fails(self):
        self.fake("docker", 'echo "#5 [front-build 3/4] RUN npm ci"')
        result = self.run_script("build_images.sh", self.artifacts())
        self.assertEqual(result.returncode, 1)
        self.assertIn("recompilé", result.stderr)

    def test_without_artifacts_the_build_stages_compile(self):
        self.fake("docker", 'echo "#5 [front-build 3/4] RUN npm ci"')
        result = self.run_script("build_images.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("--build-context", self.calls())


if __name__ == "__main__":
    unittest.main()
