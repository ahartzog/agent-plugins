# Changelog

All notable changes to the **scout-generator-critic-mediator** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for change and versioning discipline.

## [0.3.0] — 2026-08-03

### Changed
- **Plugin renamed** `sgcm` → `scout-generator-critic-mediator`. The four-letter acronym was opaque to anyone who hadn't already read the docs — the plugin name now says what it is, which matters for discovery in a public marketplace. **Breaking for install commands:** use `claude plugin install scout-generator-critic-mediator@ahartzog`. Skill and command names are unchanged — `/sgcm`, `/gcm`, `/cm`, `/m` still work, and daily usage is unaffected. Only the fully-qualified form lengthens (`sgcm:gcm` → `scout-generator-critic-mediator:gcm`).
- Marketplace renamed `ahartzog-skills` → `ahartzog`; all install pointers updated.

## [0.2.0] — 2026-07-12

### Added
- **Prompt Interpolation Safety** (`references/orchestration.md`) — guidance for any stage that injects upstream findings into a downstream agent's prompt. A mis-escaped/unresolved `${var}` is a silent failure: the verifier runs against no findings and reports all-clear. Fix: enumerate the claims to check as explicit prose (don't rely solely on injection) and assert the findings block is non-empty before dispatch. Surfaced by a hardening review.

## [0.1.0] — 2026-07-11

Initial release. Pre-1.0: the mode surface and confidence rubric may still change.

### Added
- Scout-Generator-Critic-Mediator orchestration: composable multi-agent verification rounds with structured checklists and 10–100 confidence scoring.
- Four entry points: `/sgcm` (full loop), `/sgcm:gcm`, `/sgcm:cm`, `/sgcm:m` (progressively narrower levels).
