#!/usr/bin/env python3
"""Fixture tests for extract_session.py and link_inert_refs.py.

    python3 -I plugins/second-brain/skills/second-brain/scripts/test_scripts.py
"""

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import extract_session  # noqa: E402
import link_inert_refs as lir  # noqa: E402


class ProjectSlug(unittest.TestCase):
    def test_slash_and_dot(self):
        self.assertEqual(extract_session.project_slug("/Users/me/.claude"), "-Users-me--claude")

    def test_underscore(self):
        # Claude Code hyphenates every non-alphanumeric, so a slug that keeps the
        # underscore names a folder that does not exist (issue #9).
        self.assertEqual(extract_session.project_slug("/Users/me/my_vault"), "-Users-me-my-vault")

    def test_space(self):
        self.assertEqual(
            extract_session.project_slug("/Users/me/Second Brain"), "-Users-me-Second-Brain"
        )

    def test_find_transcript_with_underscore_cwd(self):
        with tempfile.TemporaryDirectory() as tmp:
            projects = os.path.join(tmp, "projects")
            cwd = os.path.join(tmp, "my_vault")
            os.makedirs(cwd)
            d = os.path.join(projects, extract_session.project_slug(cwd))
            os.makedirs(d)
            open(os.path.join(d, "abc.jsonl"), "w").close()
            self.assertEqual(
                extract_session.find_transcript(cwd, projects_dir=projects),
                os.path.join(d, "abc.jsonl"),
            )


def write(root, rel, text="# x\n"):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(text)


class Resolve(unittest.TestCase):
    def idx(self, *rels):
        with tempfile.TemporaryDirectory() as tmp:
            for r in rels:
                write(tmp, r)
            return lir.index_vault(tmp)

    def test_unique_bare(self):
        self.assertEqual(lir.resolve("foo.md", self.idx("area/foo.md"), "src.md"),
                         ("area/foo", "unique"))

    def test_path_qualified_single(self):
        self.assertEqual(lir.resolve("ops/notes.md", self.idx("a/ops/notes.md"), "src.md"),
                         ("a/ops/notes", "path-qualified"))

    def test_path_qualified_exact_wins(self):
        idx = self.idx("ops/notes.md", "a/ops/notes.md")
        self.assertEqual(lir.resolve("ops/notes.md", idx, "src.md"), ("ops/notes", "path-qualified"))

    def test_path_qualified_folder_boundary(self):
        # `ops/notes` must not resolve to `devops/notes` (issue #11, part 1).
        self.assertEqual(lir.resolve("ops/notes.md", self.idx("devops/notes.md"), "src.md"),
                         (None, "unresolved-path"))

    def test_path_qualified_ambiguous_refuses(self):
        # Two folders share the suffix: refuse and surface it (issue #11, part 2).
        idx = self.idx("a/ops/notes.md", "b/ops/notes.md")
        self.assertEqual(lir.resolve("ops/notes.md", idx, "src.md"), (None, "ambiguous-2"))


class ConvertLine(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        write(self.tmp.name, "area/foo.md")
        self.idx = lir.index_vault(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def conv(self, line, in_table=False):
        return lir.convert_line(line, self.idx, "src.md", in_table)

    def test_backtick_converts(self):
        new, done, _ = self.conv("read `foo.md` first")
        self.assertEqual(new, "read [[area/foo|foo.md]] first")
        self.assertEqual(len(done), 1)

    def test_existing_markdown_link_untouched(self):
        # Issue #10: a working link whose text is a filename is not inert.
        line = "x [`foo.md`](area/foo.md) y"
        new, done, _ = self.conv(line)
        self.assertEqual(new, line)
        self.assertEqual(done, [])

    def test_existing_see_link_untouched(self):
        line = "[see foo.md](area/foo.md)"
        new, done, _ = self.conv(line)
        self.assertEqual(new, line)
        self.assertEqual(done, [])

    def test_existing_wikilink_untouched(self):
        line = "[[area/foo|foo.md]]"
        new, done, _ = self.conv(line)
        self.assertEqual(new, line)
        self.assertEqual(done, [])

    def test_mixed_line_converts_only_the_free_part(self):
        new, done, _ = self.conv("[`foo.md`](area/foo.md) and also `foo.md`")
        self.assertEqual(new, "[`foo.md`](area/foo.md) and also [[area/foo|foo.md]]")
        self.assertEqual(len(done), 1)

    def test_see_prose_keeps_case_and_spacing(self):
        # Issue #10, second half: "See" must not come out as "see".
        new, _, _ = self.conv("See  foo.md for details.")
        self.assertEqual(new, "See  [[area/foo|foo.md]] for details.")

    def test_table_cell_escapes_pipe(self):
        new, _, _ = self.conv("| `foo.md` |", in_table=True)
        self.assertEqual(new, "| [[area/foo\\|foo.md]] |")


class EndToEnd(unittest.TestCase):
    def test_apply_rewrites_only_inert_refs(self):
        with tempfile.TemporaryDirectory() as tmp:
            write(tmp, "area/foo.md")
            write(tmp, "a/ops/notes.md")
            write(tmp, "b/ops/notes.md")
            src = "# src\n[`foo.md`](area/foo.md)\nread `foo.md`\nsee `ops/notes.md`\n"
            write(tmp, "src.md", src)
            r = subprocess.run(
                [sys.executable, "-I", os.path.join(HERE, "link_inert_refs.py"),
                 "--root", tmp, "--apply"],
                capture_output=True, text=True,
            )
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            with open(os.path.join(tmp, "src.md"), encoding="utf-8") as fh:
                got = fh.read()
            self.assertEqual(
                got, "# src\n[`foo.md`](area/foo.md)\nread [[area/foo|foo.md]]\nsee `ops/notes.md`\n"
            )
            self.assertIn("need a human decision", r.stdout)
            self.assertIn("`ops/notes.md`  (ambiguous-2)", r.stdout)


if __name__ == "__main__":
    unittest.main()
