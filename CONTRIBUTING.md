# Contributing

This repo is Alek Hartzog's personal Claude Code plugin marketplace (`ahartzog`). It ships three plugins: **second-brain**, **apiary**, and **scout-generator-critic-mediator**. This file is the authoritative guide for anyone — human or agent — changing a plugin. Individual plugins may add stricter rules of their own (e.g. `plugins/apiary/CONTRIBUTING.md` requires scenario verification).

## The Rule: every skill change ships a changelog entry + a version bump

**When you change a plugin's content or behavior, you must, in the same change:**

1. Add an entry to that plugin's `CHANGELOG.md`.
2. Bump the `version` in that plugin's `.claude-plugin/plugin.json` per SemVer (below).

There is no separate "publish" step in this marketplace — a `git pull` + `claude plugin marketplace update` is the release. So every pushed change to a plugin is effectively a release, and every release needs a version and a changelog line. Don't batch changes under an ever-growing "Unreleased" heading; bump as you go.

**What counts as a plugin change** (needs changelog + bump): edits to any `SKILL.md`, `references/`, `protocol/`, `assets/`, templates, or the plugin's own `README.md` / `DESIGN-GOALS.md` when they change guidance a user relies on.

**What does not** (no bump needed): edits to repo-level meta — this file, the root `README.md`, the root `CLAUDE.md`, or `.gitignore`. Adding the `CHANGELOG.md` scaffold to a plugin for the first time is baseline setup, not a versioned change.

## Choosing a version bump (SemVer for skills)

A skill has no code API, so version the **contract with the user and the on-disk artifacts it generates**:

| Bump | When |
|------|------|
| **MAJOR** (`X.0.0`) | Breaking: a generated-artifact schema gains a required field, a mode is removed or renamed, or existing hubs/agents need migration. For apiary, new required `hive.yml` fields are always major and need a `mode-upgrade.md` migration. |
| **MINOR** (`x.Y.0`) | New mode, new workflow pattern, new template capability, or a materially expanded reference — additive, no migration required. Substantive docs additions (e.g. a new README techniques section) are minor. |
| **PATCH** (`x.y.Z`) | Bug fixes, wording, drift corrections, small clarifications — behavior converges on what was already intended. |

Pre-1.0 plugins (e.g. scout-generator-critic-mediator at `0.x`) may make breaking changes in a minor bump; say so in the changelog.

## Changelog format

Newest release on top. Use [Keep a Changelog](https://keepachangelog.com/) categories — `Added` / `Changed` / `Fixed` / `Removed` / `Deprecated`. Each release header carries the version and an ISO date:

```markdown
## [1.2.0] — 2026-07-20

### Added
- ...

### Fixed
- ...
```

Write entries for the reader deciding whether to run `/second-brain improve` (or the equivalent) after pulling — say what changed and whether it affects their existing setup.

## marketplace.json

`.claude-plugin/marketplace.json` carries a single marketplace-level `metadata.version` and the plugin lineup + descriptions. Bump `metadata.version` only when the **lineup or a marketplace-facing description changes** — not on every internal plugin change. Per-plugin versions live in each `plugin.json`, which is the source of truth.

## Before you commit

- **Validate all JSON manifests:**
  ```bash
  python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]"
  ```
  (There is no CI yet — a `.circleci/validate_plugins.py` is referenced in apiary's CONTRIBUTING but not present. Run the check by hand.)
- **Verify plugin.json `version` matches the top of that plugin's CHANGELOG.md.**
- **Verify the current branch** before committing, especially in worktrees. Commit or push only when explicitly asked.
