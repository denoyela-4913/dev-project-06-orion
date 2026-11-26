"""Tests de coverage_gate.py. Lancement: python3 -m unittest discover -s scripts"""
import unittest

import coverage_gate as gate

# Deux fichiers: a.ts, 4 lignes dont 3 couvertes, 2 branches dont 1 couverte (ligne 2); b.ts jamais exécuté.
LCOV = """SF:src/app/a.ts
DA:1,1
DA:2,3
DA:3,1
DA:4,0
BRDA:2,0,0,3
BRDA:2,0,1,0
end_of_record
SF:src/app/a.html
DA:1,0
end_of_record
SF:src/app/b.ts
DA:1,0
BRDA:1,0,0,-
end_of_record
"""

JACOCO = """<report name="r"><package name="com/x"><sourcefile name="A.java">
<line nr="3" mi="0" ci="4" mb="1" cb="1"/>
<line nr="4" mi="2" ci="0" mb="0" cb="0"/>
</sourcefile></package></report>"""

DIFF = """diff --git a/front/src/app/a.ts b/front/src/app/a.ts
--- a/front/src/app/a.ts
+++ b/front/src/app/a.ts
@@ -1 +1,2 @@
-old
+new
+new
@@ -9,2 +10,0 @@
-removed
-removed
@@ -12 +13 @@
-old
+++ a line of code starting with two plus signs
diff --git a/gone.ts b/gone.ts
--- a/gone.ts
+++ /dev/null
@@ -1 +0,0 @@
-old
"""


class ReportTests(unittest.TestCase):
    def test_lcov_keeps_typescript_only_like_sonar(self):
        report = gate.read_lcov(LCOV, 'front/')

        self.assertEqual(sorted(report), ['front/src/app/a.ts', 'front/src/app/b.ts'])
        self.assertEqual(gate.totals(report), (4, 8))  # 3 lignes + 1 branche couvertes, sur 5 lignes + 3 branches

    def test_jacoco_counts_lines_and_branches(self):
        report = gate.read_jacoco(JACOCO, 'back/src/main/java/')

        self.assertEqual(list(report), ['back/src/main/java/com/x/A.java'])
        self.assertEqual(gate.totals(report), (2, 4))

    def test_diff_gives_added_line_numbers_per_file(self):
        self.assertEqual(gate.added_lines(DIFF), {'front/src/app/a.ts': {1, 2, 13}})

    def test_new_code_counts_only_added_lines(self):
        report = gate.read_lcov(LCOV, 'front/')

        # Ligne 2: couverte, avec une branche sur deux. Ligne 4: non couverte. Ligne 99: non exécutable.
        self.assertEqual(gate.totals(report, {'front/src/app/a.ts': {2, 4, 99}}), (2, 4))


class VerdictTests(unittest.TestCase):
    def results(self, front=(90, 100), back=(90, 100), front_new=(9, 10), back_new=(0, 0)):
        return [('front', 'global', front), ('front', 'nouveau code', front_new),
                ('back', 'global', back), ('back', 'nouveau code', back_new)]

    def test_threshold_is_reached_at_exactly_80_percent(self):
        self.assertEqual(gate.failures(self.results(front=(80, 100)), 80), [])

    def test_each_rate_below_80_percent_is_a_failure(self):
        found = gate.failures(self.results(back=(7999, 10000), front_new=(1, 2)), 80)

        self.assertEqual([(part, scope) for part, scope, _ in found], [('front', 'nouveau code'), ('back', 'global')])

    def test_nothing_to_cover_in_new_code_is_not_a_failure(self):
        self.assertEqual(gate.failures(self.results(front_new=(0, 0)), 80), [])

    def test_failures_do_not_block_while_not_blocking(self):
        self.assertEqual(gate.exit_code(self.results(back=(1, 100)), 80, blocking=False), 0)

    def test_failures_block_once_blocking(self):
        self.assertEqual(gate.exit_code(self.results(back=(1, 100)), 80, blocking=True), 1)

    def test_ready_to_block_needs_both_global_rates(self):
        self.assertFalse(gate.both_parts_reached(self.results(back=(79, 100)), 80))
        self.assertTrue(gate.both_parts_reached(self.results(front_new=(0, 10)), 80))


if __name__ == '__main__':
    unittest.main()
