# Changelog

All notable changes to the **repo-wrap-kit** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for change and versioning discipline.

## [0.1.0] — 2026-09-29

### Added
- `design-repo-wrap` skill: surveys a repository, asks the owner four questions (authority, homes for learnings, agents and name, off-limits), designs the routing table and phases, writes the repo's own `repo-wrap` skill from a template, makes it callable for each agent (`.agents/skills/` source, `.claude/skills` symlink, two instruction lines) and verifies it with discovery probes, a `report-only` dry run and a link check.
- Proposal mode: a read-only survey that writes `survey.md`, `decisions.md`, `routing.md` and a draft `SKILL.md` outside the repo.
- References: discovery survey table, learning loop (startup paths, routing table, retro questions, harvest input, instructions-file size rule), wrap anatomy (seven phases, ordering constraints, landing styles by integration type, hazards with survey triggers, report-only mode), and per-agent install facts for Claude Code, Codex, Gemini CLI, Cursor and Copilot, checked against vendor docs on 2026-09-29.
- Worked example: the StickWars VR `repo-wrap`, mapped to the anatomy with the survey fact behind each choice.

Pre-1.0: tested in three proposal-mode runs on scratch clones of two repos (a SvelteKit PWA with deploy-on-push, and a local-only repo with no remote or tracker). The full install path has not yet run end to end in a new repo.
