# {HIVE_NAME} Hive Mind

> 📒 Part of the [Meridian Systems Hive Mind Registry]({REGISTRY_URL}) — the index of every team Hive Mind, what each is for, and how to use it.

{DESCRIPTION}

This repository is a **collectively-maintained** AI knowledge base. Claude Code loads the persona from `PROTOCOL/agent-definition.md`, grounds its answers in `knowledge/`, and captures new facts in `_inbox/` for Parliament to triage.

## What Lives Here

{HIVE_PURPOSE}

Knowledge outside this scope likely belongs in a different Hive — see the [registry]({REGISTRY_URL}) for the full set.

## Quick Start

```bash
git clone {GIT_REMOTE}
cd {HIVE_SLUG}
claude  # or open in Claude Code / VSCode with Claude extension
```

Inside Claude Code:

```
/{HIVE_SLUG}
```

That routes through the Apiary (Hive Parent Protocol) — it loads the persona, reads `hive.yml`, and dispatches to the right workflow (ask / orient / status / contribute).

## The One Rule

**NEVER edit `knowledge/` files directly.** All contributions go through `_inbox/`:

1. Write to `_inbox/YYYY-MM-DD-<gh-user>-<topic>.md` with `status: ready` in frontmatter.
2. Tag entries (`[link]`, `[architecture]`, `[status]`, `[correction]`, `[person]`, `[tracker]`, `[process]`, `[contradiction]`, `[strategy]`, `[meta]`).
3. Commit and push. Parliament processes inbox files into knowledge files via PR.

Direct edits to `knowledge/` bypass triage and will be reverted.

## Repository Layout

```
{HIVE_SLUG}/
├── hive.yml                  # Identity: slug, codeowners, slack channel
├── CLAUDE.md                 # Project-scoped Claude Code instructions
├── README.md                 # You are here
├── .claude/settings.json     # Hooks: sync on session start, rebase before push
├── .signal/config.yml       # Signal bot Slack channel
├── PROTOCOL/
│   ├── agent-definition.md   # Persona, routing, constraints
│   └── extensions/           # (optional) hive-local workflow extensions
├── knowledge/                # Curated knowledge files (Parliament-maintained)
│   └── {subdomain}/
│       └── reference-library.md  # (optional) Retrieval-trigger index for this sub-domain
├── _inbox/                   # Contributions land here
│   ├── _completed/           # Post-Parliament archive
│   └── _quarantine/          # Sentinel-flagged items (classification / injection / PII)
├── _custodian/
│   ├── config.yml            # Parliament thresholds
│   └── reports/              # Parliament run logs
└── _metrics/                 # Usage and flywheel telemetry
```

## Sources

Primary source material — meeting transcripts and verbatim documents — deposited directly. Sources bypass Parliament: they are ground truth, not claims requiring validation. Learnings from sources enter `knowledge/` through the normal inbox→Parliament path. Sources live in their own directory (not under `knowledge/`), organized by doc-type.

```
sources/
├── index.md               # Single manifest of all sources (discoverability)
├── meeting-transcripts/    # Verbatim transcripts (pasted text)
├── document/  icd/  sow/  spec/  decision/ ...  # created on demand
```

**Depositing:**
- **Text / markdown** (pasted transcript, notes): Deposit workflow — `/{HIVE_SLUG}` → "deposit this transcript".
- **Binary documents** (PDF, PPTX, DOCX, XLSX): `/extract:ingest <file> --hive .` — parses the file, LFS-tracks the binary in `sources/`, and writes a distilled inbox entry. The Apiary does not parse binaries itself.

Binary sources are tracked with **Git LFS**; text sources are normal git files. Note: the pre-push Sentinel scans text sources, but **cannot** scan LFS binary content — confirm binary documents are safe to store at this Hive's classification ceiling before depositing.

## Classification & Security

{CLASSIFICATION_SECTION_README}

- **No personal editorial commentary** about named individuals. Professional role + contact info only.

Details in the Apiary upstream `protocol/security-policy.md`.

<!--
  Create mode substitutes {CLASSIFICATION_SECTION_README} with one of:

  UNCLASSIFIED Hive (default):
    "- **No classified content in this repo.** CUI/FOUO material is referenced
       by storage-system path only. Three enforcement layers: session agent
       detection on contribute; GHE pre-receive hook rejection; Parliament
       Sentinel intake scan."

  Classified Hive (max_level: CUI, marking_required: true):
    "- **This Hive is authorized for content up to {MAX_LEVEL}.** Storage tier:
       {STORAGE_TIER}. Every knowledge and inbox file carries a frontmatter
       `classification:` field; files with classified content also carry a
       matching first-line banner. Unmarked classified content is quarantined
       by Parliament Sentinel. Content above {MAX_LEVEL} is always rejected."
-->


## Contribution Categories

| Tag | What it is | Path |
|-----|------------|------|
| `[link]` | New document / page URL | Fast — auto-merge |
| `[person]` | New person / role | Fast — auto-merge |
| `[tracker]` | New tracker / channel | Fast — auto-merge |
| `[status]` | Status update | Deliberation (3 critics) |
| `[correction]` | Factual correction with source | Deliberation |
| `[architecture]` | Architectural claim | Deliberation |
| `[process]` | Process / principle change | Deliberation |
| `[contradiction]` | Contradicts existing fact | Deliberation |
| `[strategy]` | Strategic / priority recommendation | Deliberation |
| `[meta]` | Observation about the skill or protocol | Deliberation + CODEOWNERS |

Full triage rules: Apiary upstream `protocol/triage-policy.md`.

## Upstream Protocol

Governed by the Apiary (Hive Parent Protocol). The Apiary provides:

- `protocol/design-goals.md` — north-star principles
- `protocol/security-policy.md` — classification discipline / PII defense-in-depth
- `protocol/triage-policy.md` — contribution routing rules
- `protocol/operational-model.md` — session → accumulation → incorporation loop
- `protocol/knowledge-schema.md` — knowledge-file frontmatter schema
- `protocol/tool-tiers.md` — graceful tool-availability degradation

When working in this repo, `/{HIVE_SLUG}` dispatches through the Apiary for protocol. Only domain-specific additions live here in `PROTOCOL/extensions/` — Hive-local named workflows go in `PROTOCOL/extensions/workflows/` and are wired up via `extensions.workflows` in `hive.yml` (authoring guide: `references/authoring-workflow-extensions.md` in the Apiary skill).

For the full set of Hives across Meridian Systems — and which one owns a given topic — see the [Hive Mind Registry]({REGISTRY_URL}).

## Contribute

Questions or corrections that don't fit the inbox — open an issue or PR. For protocol changes, PRs must be reviewed by CODEOWNERS (see `hive.yml`).

Slack: `#{SLACK_CHANNEL}`.
