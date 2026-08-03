# Content Source Catalog — Personal / Household Edition

This is the superset of content sources available for domain agents. During the Create interview, present relevant sources as a checklist for the user to select from.

**This catalog is hub-specific.** The version bundled here reflects a household setup. When adopting a new hub, regenerate this catalog from what's actually installed — `claude mcp list`, installed plugins, and the user's stated sources of truth.

Each source has a **readiness** indicator:
- **Green** — reliable, well-supported, easy to set up
- **Yellow** — works but has caveats (manual steps, broken connectors, partial data)
- **Red** — no good integration today; reference by URL or manual export only

**Key principle:** Yellow and Red sources are improvement opportunities. If you improve a connector, the flywheel grows.

## Source Catalog

### Green — Ready to Use

| Source | Access Method | What It Provides | Notes |
|--------|--------------|------------------|-------|
| **Monarch Money** | `mcp__monarch__*` MCP tools | Accounts, balances, transactions, budgets, cashflow, holdings | Financial domain's live truth. Watch known data-quality quirks (duplicate accounts, broken loan connectors) — document them in the agent's Domain Context |
| **Google Workspace** | `mcp__workspace-mcp__*` MCP tools (or claude.ai connectors) | Gmail, Calendar, Drive, Docs, Sheets, Tasks, Contacts | Calendar is a high-value truth source for family logistics; Drive for document archive |
| **Obsidian Vault** | Filesystem Read/Glob/Grep | All knowledge files, tasks, trip plans, logs | Filesystem always works; Obsidian MCP optional. Tasks plugin format for actionables |
| **Local files & exports** | Read/Bash | PDFs (statements, EOBs, itineraries), JSON data exports, SQLite stores | Keep raw exports immutable; agents write synthesis, not source edits |
| **GitHub** | `gh` CLI via Bash | Personal repos, issues, PRs | For code projects (games, viewers, MCP servers) |
| **Web research** | WebSearch / WebFetch | Prices, FDA status, contractor reputation, event listings, tax rules | Cite URLs; re-verify time-sensitive claims in-session |

### Yellow — Works with Caveats

| Source | Access Method | What It Provides | Caveats |
|--------|--------------|------------------|---------|
| **MyChart (Epic)** | Manual PDF/ZIP export → vault | Labs, visit notes, clinical records | No live MCP yet. Export → `Medical/` synthesis pass. Improvement opportunity: Health Record MCP (FHIR) |
| **Apple Health / HR data** | Periodic export → JSON/SQLite ingest | Heart rate, HRV, workouts, ECG | Export is manual; ingest scripts live alongside the data. Within-minute HR analysis needs the raw files, not summaries |
| **iMessage** | `imessage` plugin (if configured) | Family coordination, reminders via text | Access policy controls; useful as a nudge channel more than a knowledge source |
| **School / activity portals** | Manual check, reference by URL | Schedules, announcements | No API. Store URLs + check cadence in knowledge files |
| **Insurance portals (BCBS etc.)** | Manual EOB download | Claims, EOBs for reconciliation | Reference by claim number; reconcile-before-pay workflow is manual |

### Red — Reference Only (No Integration)

| Source | How to Reference | Improvement Opportunity |
|--------|-----------------|------------------------|
| **Shareworks / equity portal** | Manual check; live FMV must be pulled at execution time | Even a screen-scrape checklist beats a stale workbook — never size an exercise from a cached 409A |
| **Pharmacy / GoodRx pricing** | WebSearch per question | Price-check MCP would help recurring prescription audits |
| **Utility / HOA portals** | URLs in knowledge files | Low volume; probably fine manual |
| **Smart home / security systems** | Manual | Niche; revisit if a domain needs it |

## How Sources Wire to Agents

During the Create/Adopt interview, selected sources map to:

1. **Tools list** — add necessary tools to the agent's frontmatter (MCP tools are available by default; add `Skill` if invoking other skills)
2. **Domain Context section** — source-specific access instructions, fully-qualified MCP tool names, and known quirks
3. **Routing guidance** — when to pull live data vs. answer from knowledge files (pull when the answer depends on current state; don't pull for strategy questions)
4. **Knowledge files** — reference entries pointing to the live source, never copies of its data

## Adding New Sources

When you discover a new content source:

1. Check if an MCP server, plugin, or CLI already exists for it
2. If yes → add it to the agent's Domain Context and routing
3. If no → consider building one (that's the Persist → Share loop)
4. Update this catalog with the new source and an honest readiness level — don't inflate readiness; "works with caveats" beats a Green that fails
