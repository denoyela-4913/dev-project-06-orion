"""Tests des garde-fous des scripts de lancement des conteneurs et de construction des images.

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


class RunTests(ScriptCase):
    def test_bad_arguments_are_refused_before_any_action(self):
        for command in (
            ("run_back.sh", "--port", "70000"),
            ("run_back.sh", "--port", "abc"),
            ("run_back.sh", "--port"),
            ("run_front.sh", "--unknown"),
            ("run_front.sh", "--api-url", "http://x", "--upstream", "back:8080"),
            ("run_all.sh", "--front-port", "8080"),
            ("ci_test.sh",),
            ("ci_test.sh", "database"),
        ):
            with self.subTest(command=command):
                result = self.run_script(*command)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.calls(), "")

    def test_ports_and_extra_options_reach_the_container(self):
        result = self.run_script("run_back.sh", "--port", "9090", "--env", "A=1", "--", "--memory", "1g")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--publish 127.0.0.1:9090:8080", self.calls())
        self.assertIn("--env A=1 --memory 1g microcrm-back:local", self.calls())

    def test_a_network_address_gets_a_warning_instead_of_a_link(self):
        result = self.run_script("run_back.sh", "--bind", "192.0.2.10")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("docker exec microcrm-back wget", self.calls())
        self.assertIn("sans chiffrement", result.stdout)

    def test_https_front_publishes_the_tls_port(self):
        result = self.run_script("run_front.sh", "--https", "--port", "8443")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--publish 127.0.0.1:8443:443 --env SITE_ADDRESS=localhost", self.calls())

    def test_an_existing_container_is_not_replaced(self):
        self.fake("docker")
        result = self.run_script("run_back.sh")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("docker run", self.calls())
        self.assertNotIn("docker rm", self.calls())

    def test_stop_leaves_a_foreign_container_alone(self):
        # Le conteneur existe mais n'a pas le label de ces scripts.
        self.fake("docker")
        result = self.run_script("run_back.sh", "--stop", "--name", "someone-else")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("docker rm", self.calls())

    def test_a_front_that_fails_also_stops_the_back(self):
        # Le back répond ; `docker run` échoue pour le front. Après son lancement, le back « existe ».
        marker = self.bin / "back-started"
        self.fake(
            "docker",
            f'case "$*" in\n'
            f'  *"--name microcrm-front"*) exit 1 ;;\n'
            f'  "run "*) touch "{marker}" ;;\n'
            f'  "container inspect --format"*) echo 1 ;;\n'
            f'  "container inspect microcrm-back") test -f "{marker}" ;;\n'
            f'  "container inspect"*) exit 1 ;;\n'
            f"esac",
        )
        result = self.run_script("run_all.sh")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("docker rm --force microcrm-back", self.calls())


class CiTestTests(ScriptCase):
    """ci_test.sh efface des dossiers de sortie : il est joué sur une copie, hors du dépôt."""

    def run_copy(self, docker):
        self.fake("docker", docker)
        copy = self.bin / "repo" / "scripts" / "ci_test.sh"
        copy.parent.mkdir(parents=True)
        copy.write_bytes((SCRIPTS / "ci_test.sh").read_bytes())
        copy.chmod(0o755)
        return self.run_script(str(copy), "back")

    def test_the_back_runs_every_check_and_keeps_going(self):
        result = self.run_copy("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("./gradlew check --continue", self.calls())

    def test_reports_are_still_copied_after_a_failure(self):
        # Les contrôles échouent et un rapport manque : les autres sont copiés, l'échec est conservé.
        result = self.run_copy('case "$*" in "start --attach"*) exit 1 ;; "cp "*jacoco*) exit 1 ;; esac')
        self.assertEqual(result.returncode, 1, result.stderr)
        for report in ("reports/checkstyle", "reports/spotbugs"):
            self.assertIn(f":/src/build/{report} ", self.calls())

    def test_a_missing_report_fails_a_successful_run(self):
        result = self.run_copy('case "$*" in "cp "*spotbugs*) exit 1 ;; esac')
        self.assertNotEqual(result.returncode, 0)


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
