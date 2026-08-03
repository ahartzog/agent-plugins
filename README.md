# agent-plugins

Claude Code plugins for **agent memory and verification** — giving agents durable knowledge that improves with use, and adversarial review that catches what a single pass misses.

Built and used daily against a production knowledge vault; informed by 2026 research on agent memory, knowledge freshness, and eval loops.

## Plugins

| Plugin | What it does | Reach for it when |
|--------|--------------|-------------------|
| **second-brain** | Domain-agent lifecycle: `operate` (a single-sourced protocol every agent bootstraps), `create`, `adopt`, `audit`, `improve`, `add-workflow`, `wrap`. Five learning loops (A–E), custodian, golden-question evals, hook enforcement. | You want an agent that accumulates judgment over months instead of restarting cold every session — and a non-destructive on-ramp for hand-rolled agents you already have. |
| **apiary** | Multi-contributor knowledge bases ("hives"): git-backed repos with inbox → Parliament triage → curated knowledge, plus Sentinel scanning. | More than one person (or machine) contributes to the same knowledge base and you need triage and attribution rather than merge conflicts. |
| **scout-generator-critic-mediator** | Composable multi-agent verification rounds with structured checklists and 10–100 confidence scoring. Four levels: `/sgcm` (full loop), `/gcm`, `/cm`, `/m` (progressively narrower). | You want adversarial verification layered onto any task — code review, audits, plan execution — instead of trusting a single generation pass. |

`second-brain` and `apiary` are the same idea at two scales: single-author and multi-contributor. `scout-generator-critic-mediator` is orthogonal and composes with either.

### Design stance

- **Plain markdown is the source of truth.** No embeddings-as-memory, no proprietary store. Everything is greppable, diffable, and yours.
- **Not Obsidian-specific.** Obsidian features (wikilinks, landing pages, MCP tools) are used when present, never required.
- **Agent files must not grow monotonically.** A rule the agent works around is a bug in the rule — the protocol prescribes eviction, not just accretion.

## Install

```bash
claude plugin marketplace add ahartzog/agent-plugins

claude plugin install second-brain@ahartzog
claude plugin install apiary@ahartzog
claude plugin install scout-generator-critic-mediator@ahartzog
```

Then run `/second-brain operate` (or `create`, `adopt`, `audit`, `improve`, `add-workflow`, `wrap`) from any directory. If you already have hand-rolled agents, start with `adopt` — it preserves accumulated judgment instead of flattening it into a template.

Auto-update pulls from `main`. To force a refresh:

```bash
claude plugin marketplace update ahartzog
```

## Contributing

Every change to a plugin ships a `CHANGELOG.md` entry **and** a `version` bump in that plugin's `.claude-plugin/plugin.json`, in the same change. See [CONTRIBUTING.md](CONTRIBUTING.md) for the rule and how to pick a bump level; `apiary` adds a stricter per-plugin guide. Agents editing this repo load [CLAUDE.md](CLAUDE.md), which points here.

## License

MIT — see each plugin's `LICENSE`.

## Backlog

Parked improvements — captured so they aren't lost, not scheduled.

- **Per-machine setup registry.** A maintained "new machine setup" page: what a fresh `git clone` restores by itself vs. a table of every per-machine dependency (credentials, MCP registrations, plugin installs, local tools, hook symlinks) with re-setup pointers — plus the rule that keeps it true: *any session that adds a per-machine dependency updates the registry in the same session.*
- **Second-contributor capture channel + identity handling.** When a second person queries or contributes directly: (a) person-specific advisors need an **identity interrupt** — confirm who's asking before advising when the speaker is ambiguous, even in autonomous flows (matters most where two people hold opposing preferences); (b) the apiary inbox architecture is the reference design for the capture channel; (c) carry an `author-type: human|agent` field through any Parliament merge so attribution survives.
- **Retrieval layer over markdown.** Whether to add a local retrieval index (BM25 + local vector + rerank) as a disposable cache over the markdown — markdown stays the only source of truth, nothing leaves the machine. Under evaluation; the design objection to keep is *memory-in-embeddings*, which retrieval-over-markdown avoids.
