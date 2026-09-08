#!/usr/bin/env python3
"""Convert inert filename references into real links.

An *inert reference* is a filename mentioned in backticks (``foo.md``) or as bare
prose ("see foo.md"). It reads like a pointer but is not traversable. Converting
one is the cheapest link-graph repair there is, because the author already decided
the pointer belonged at that spot — this only changes the markup.

This is deliberately NOT a model task. Resolving a filename to a path, detecting
basename collisions, and rewriting markup are mechanical. What is *not* mechanical
is deciding whether two files should be related at all; that stays with the
Connections trigger in protocol/learning-loops.md.

Dry-run by default. Nothing is written without --apply.

    # what would change, vault-wide
    python3 link_inert_refs.py --root "/path/to/vault" --scope "Second Brain"

    # one domain, then write it
    python3 link_inert_refs.py --root "/path/to/vault" --scope "Second Brain/Autonomy" --apply

Exit codes: 0 conversions were found (or applied), 1 nothing to convert, 2 bad usage.
Note the polarity: 0 does NOT mean "clean" — it means there was work to do. Do not
wire this into a pass/fail gate without inverting it.
"""

import argparse
import os
import re
import sys
from collections import defaultdict

# A backticked filename, or bare "see foo.md" prose. Deliberately narrow: we only
# touch references that look like a bare filename or a vault-ish relative path.
BACKTICK = re.compile(r"`([A-Za-z0-9][^`\n]{0,200}?\.md)`")
SEE_PROSE = re.compile(r"\bsee\s+([A-Za-z0-9][A-Za-z0-9 _./&()-]{0,120}?\.md)\b", re.I)

# References that name something outside the vault. Converting these would create a
# dead link, which is strictly worse than a backtick — a backtick is honest about
# not being a link.
EXTERNAL = re.compile(
    r"""^(
      ~/            |   # home-relative: ~/src/platform/docs/...
      /             |   # absolute
      \.\./         |   # escapes the scope
      https?://     |
      docs/         |   # repo-relative docs trees
      data-model/   |
      src/          |
      examples/     |
      internal-documentation/
    )""",
    re.X,
)

SKIP_DIRS = {
    ".git", ".obsidian", ".trash", "node_modules", ".worktrees",
    # Historical and retired content. The shared rule: a dated snapshot names files
    # as evidence of a past state, and a retired domain is deliberately unrouted.
    # Linking either one promotes it back into live routing, which is the opposite
    # of what archiving meant.
    "_reports", "_Templates", "_archive", "archived", "superpowers",
}


def md_files(root, rel_scope=None):
    base = os.path.join(root, rel_scope) if rel_scope else root
    out = []
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for f in filenames:
            if f.endswith(".md"):
                out.append(os.path.join(dirpath, f))
    return sorted(out)


def index_vault(root):
    """basename (no .md) -> [vault-relative path without .md]. Vault-wide, because a
    reference in one domain legitimately points at a note in another."""
    idx = defaultdict(list)
    for p in md_files(root):
        rel = os.path.relpath(p, root)
        idx[os.path.basename(rel)[:-3]].append(rel[:-3])
    return idx


def in_code_fence(lines, i):
    """A link inside a fenced block does not render, so leave those alone."""
    return sum(1 for ln in lines[:i] if ln.lstrip().startswith("```")) % 2 == 1


def resolve(ref, idx, source_rel):
    """-> (vault_path_without_md, reason). vault_path None means: do not convert."""
    if EXTERNAL.match(ref):
        return None, "external"
    stem = ref[:-3] if ref.endswith(".md") else ref
    # A reference that already carries a folder path: trust it if it resolves.
    if "/" in stem:
        norm = os.path.normpath(stem)
        for cand in idx.get(os.path.basename(norm), []):
            if os.path.normpath(cand).endswith(norm):
                return cand, "path-qualified"
        return None, "unresolved-path"
    matches = idx.get(stem, [])
    if not matches:
        return None, "no-vault-file"
    if len(matches) == 1:
        return matches[0], "unique"
    # Ambiguous basename. Prefer a match in the source's own directory, then its
    # domain. Never guess beyond that — a wrong pick is a silently wrong link.
    src_dir = os.path.dirname(source_rel)
    same_dir = [m for m in matches if os.path.dirname(m) == src_dir]
    if len(same_dir) == 1:
        return same_dir[0], "ambiguous-same-dir"
    domain = source_rel.split(os.sep)[0] if os.sep in source_rel else ""
    same_domain = [m for m in matches if m.startswith(domain + os.sep)] if domain else []
    if len(same_domain) == 1:
        return same_domain[0], "ambiguous-same-domain"
    return None, f"ambiguous-{len(matches)}"


def convert_line(line, idx, source_rel, in_table):
    """-> (new_line, [(ref, target, reason)], [(ref, reason)])"""
    done, skipped = [], []

    def sub(m, quoted):
        ref = m.group(1)
        target, reason = resolve(ref, idx, source_rel)
        if not target:
            skipped.append((ref, reason))
            return m.group(0)
        # Preserve the rendered text: the original read as a filename, so alias it
        # back to the filename. In a table cell the alias pipe must be escaped, or
        # it is parsed as a column separator.
        pipe = r"\|" if in_table else "|"
        done.append((ref, target, reason))
        link = f"[[{target}{pipe}{ref}]]"
        return link if quoted else f"see {link}"

    line = BACKTICK.sub(lambda m: sub(m, True), line)
    line = SEE_PROSE.sub(lambda m: sub(m, False), line)
    return line, done, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="vault root; links resolve against this")
    ap.add_argument("--scope", default=None, help="vault-relative subtree to edit (default: whole vault)")
    ap.add_argument("--apply", action="store_true", help="write changes (default: dry run)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(os.path.expanduser(args.root))
    if not os.path.isdir(root):
        print(f"not a directory: {root}", file=sys.stderr)
        return 2

    idx = index_vault(root)
    targets = md_files(root, args.scope)
    if not targets:
        print(f"no .md files under {args.scope or '.'}", file=sys.stderr)
        return 2

    n_conv = 0
    skip_tally = defaultdict(int)
    ambiguous = []
    changed_files = 0

    for path in targets:
        rel = os.path.relpath(path, root)
        # Never rewrite frontmatter: a `sources:` path is data, not prose.
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        fm_end = 0
        if lines and lines[0].strip() == "---":
            for i, ln in enumerate(lines[1:], 1):
                if ln.strip() == "---":
                    fm_end = i
                    break

        out, file_conv = list(lines), 0
        for i, line in enumerate(lines):
            if i <= fm_end or in_code_fence(lines, i):
                continue
            in_table = line.lstrip().startswith("|")
            new, done, skipped = convert_line(line, idx, rel, in_table)
            for ref, reason in skipped:
                skip_tally[reason] += 1
                if reason.startswith("ambiguous-"):
                    ambiguous.append((rel, i + 1, ref, reason))
            if done:
                out[i] = new
                file_conv += len(done)
                if not args.quiet:
                    for ref, target, reason in done:
                        print(f"  {rel}:{i+1}  `{ref}` -> [[{target}]]  ({reason})")

        if file_conv:
            changed_files += 1
            n_conv += file_conv
            if args.apply:
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write("\n".join(out))

    verb = "converted" if args.apply else "would convert"
    print(f"\n{verb} {n_conv} inert reference(s) across {changed_files} file(s)"
          f"{'' if args.apply else '  [DRY RUN — rerun with --apply]'}")
    if skip_tally:
        print("left inert:")
        for reason, count in sorted(skip_tally.items(), key=lambda kv: -kv[1]):
            print(f"  {count:>4}  {reason}")
    if ambiguous:
        print(f"\n{len(ambiguous)} reference(s) need a human decision (basename resolves to "
              f"several files, none in the source's own directory or domain):")
        for rel, ln, ref, reason in ambiguous[:40]:
            print(f"  {rel}:{ln}  `{ref}`  ({reason})")
        if len(ambiguous) > 40:
            print(f"  ... and {len(ambiguous) - 40} more")
    return 0 if n_conv else 1


if __name__ == "__main__":
    sys.exit(main())
