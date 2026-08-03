# Contributing to Second Brain

This file is loaded by any agent editing the Second Brain plugin. Follow it exactly, alongside the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) (changelog entry + version bump in the same change).

## Cross-Check Schema Changes Against Apiary

Second Brain and the [apiary](../apiary) plugin share several knowledge-layer schemas — they evolved from the same design and are kept deliberately consistent. **Any change to a shared schema here must be cross-checked against apiary to decide whether it applies there too.**

Shared surfaces to check on every schema change:

| Second Brain file | Apiary counterpart | What must stay consistent |
|---|---|---|
| `skills/second-brain/protocol/knowledge-schema.md` | `plugins/apiary/skills/apiary/protocol/knowledge-schema.md` | Frontmatter fields, `type`/`decay`/`confidence` enums, inline annotations (`[learned:]`, `[decided:]`, `[disputed:]`, `[superseded:]`, …), the reference-library entry format |
| `skills/second-brain/references/document-quality.md` | `plugins/apiary/skills/apiary/protocol/document-quality.md` | `doc_type` and `authority` enums — the field definitions must stay compatible |
| `skills/second-brain/references/mode-audit.md` | `plugins/apiary/skills/apiary/references/mode-audit.md` | Any validation/severity rule that enforces a shared schema (reference-library size cap, annotation coverage) |

**Rule:** When you touch any row above, open the counterpart file and decide explicitly: does this change apply there too? If yes, make it in the same change (or a paired follow-up) and bump both plugins. If no, state why in the changelog entry — the two schemas may diverge intentionally (apiary carries multi-writer governance — Parliament, CODEOWNERS, `extensions` — that a single-user Second Brain does not). "I didn't check" is not an acceptable answer; silent drift between the two is the failure mode this section exists to prevent.

**Known drift (as of 2026-07-30):** the two `knowledge-schema.md` files have already diverged (apiary carries `extensions.knowledge_schema` hive.yml hooks and a different frontmatter shape; the 2.0.0 `[decided:]` expansion and reference-library table format have not yet been mirrored). Treat apiary sync as an explicit follow-up item, not an assumed state.

## Other Requirements

- **Version bump required.** Bump `.claude-plugin/plugin.json` per the repo-level CONTRIBUTING, with a matching `CHANGELOG.md` entry in the same change.
- **Validate JSON** before committing: `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]"` from the repo root.
- **Respect the hot-path budgets** in [DESIGN-GOALS.md](DESIGN-GOALS.md) §6: `references/mode-operate.md` under ~70 lines; `protocol/` files compact (learning-loops ≤ ~190, knowledge-schema ≤ ~150, triage-policy ≤ ~110). A breach either trims the file or updates the ceiling in DESIGN-GOALS with the reason, in the same change.
- **Protocol changes are load-bearing everywhere.** `protocol/` files load into every agent session of every hub via Operate mode. A wrong line there corrupts contribution behavior across all Second Brains on the next marketplace update — review accordingly.
