---
layer: PROTOCOL
type: tool-tiers
description: "Three-tier tool-availability model. The session agent detects which skills/MCPs are installed and degrades gracefully when any are missing."
last_updated: 2026-07-30
codeowners: (read from hive.yml)
---

# Tool Tiers

Not every Hive user has every tool installed. The agent must detect what's available and degrade gracefully — it should never fail closed on a missing tool when a URL fallback exists.

## Detection

On invocation, check the available-skills list (shown in the system reminder) and the MCP server list. For each tool in the standard set below, note `available: true/false`. The agent's routing table MUST reference this availability — it cannot assume a tool is present.

## Standard Tool Set

| Tool | Kind | Purpose | Fallback when missing |
|------|------|---------|------------------------|
| `jira-cli` | Skill | the organization's Jira instance — tickets, boards, epics | URL to the board/ticket; text summary from knowledge files only |
| `confluence-cli` | Skill | the organization's Confluence instance — docs, pages, spaces | URL to the page; text summary from knowledge files only |
| `sharepoint` | Skill | SharePoint sites, document libraries, and files (`*.sharepoint.us`) via MS Graph | Resolved document URL; name the document and say it was not opened |
| `box-skill` | Skill | Box cloud storage (`app.box.com`) — search, browse, read files | Resolved file/folder URL; name the document and say it was not opened |
| `quip-mcp` | MCP | Quip documents and threads (`*.quip.com`) | Resolved thread URL; name the document and say it was not opened |
| `slack-cli` | Skill | Commercial Slack | URL to slack; summarize from knowledge files |
| `chrome-auth` | Skill | Cookie-based auth for Okta-protected services (dependency for others) | Warn user, suggest install, retry |
| `outlook-macos:outlook` | Skill | macOS Outlook inbox | Not Hive-critical; skip |
| `<domain>-confluence` | MCP | A domain-specific Confluence behind a program network (VPN/enclave required) | Point to `knowledge/*/confluence-index.md` for space keys + page IDs |
| `mcp-atlassian` | MCP | Combined Confluence + Jira MCP | Use `jira-cli` + `confluence-cli` as substitutes |
| `sourcegraph-cli` | Skill | Cross-repo code search | Web Sourcegraph UI |
| `circleci` | Skill | CI builds, workflow status, logs | CircleCI UI |
| `outlook-calendar` | Skill | Calendar queries | Outlook app |

Hives add or remove entries in their `PROTOCOL/agent-definition.md` based on what's actually relevant to their domain.

## Store Kind → Tool

`protocol/routing-protocol.md` §Resolve dispatches on the store kind a catalog declares in its
frontmatter `sources[].type`. This maps that value to the tool that reaches it:

| Store kind | Tool | Search primitive → recency capability | Notes |
|---|---|---|---|
| `sharepoint` | `sharepoint` | `search <drive_id> "query"` (name/content); tenant-wide Graph `/search/query` — **keyword-first**, no modification-date ordering in the shipped path | Depends on `chrome-auth`; auth may require a browser session |
| `box` | `box-skill` | `search "query"` / `box_search_tool` — filters on modification date and returns per-hit dates; **no date ordering** | Requires the `box` CLI (Node via fnm) and a one-time `box login`. `--ancestor-folder-ids` scopes to a root; `--file-extensions` avoids selecting a large binary |
| `quip` | `quip-mcp` | `quip_search_threads` (full-text or `only_match_titles`) — **keyword-first**, no date filter or sort | MCP server is session-dependent — invoke the skill first |
| `confluence` | `confluence-cli`, `mcp-atlassian`, or a `<domain>-confluence` MCP for enclave instances | CQL (`confluence search --cql`) — **recency-capable**: `ORDER BY lastmodified`, `created`/`lastmodified` date fields | Program-gated instances need VPN; `WebFetch` fails on private-CA hosts |
| `jira` | `jira-cli` or `mcp-atlassian` | JQL (`jira-cli search`) — **recency-capable**: `ORDER BY updated DESC`, `updated >= -Nd` | — |
| `ghe` / `gitlab` | `gh` CLI / `git` / `sourcegraph-cli` | `src search` (keyword/regex) — **keyword-first**, no date in the hit payload; a modification date costs a separate `git log -1` per survivor | — |
| `public-web` | `WebFetch` | **none** — `WebFetch` retrieves a known URL; no discovery primitive | No auth |

This table is **mechanics only** — which tool opens which store, and which search primitive that
store exposes. Consistent with the mechanics-only boundary the Tool column already carries: it says
nothing about whether a document should be fetched, and the Search column says nothing about whether
a search *should* run. Both judgments belong to `routing-protocol.md` — fetch to §Extract, the
sufficiency-and-recency call that fires §Search to §Search itself. A store kind with no row here is a
gap: record it per §On no match rather than improvising a tool.

**Search capability is not uniform**, and it varies along two axes — whether the store can *filter*
to a date range, and whether it can *order* by date. The Search column above states each store's
capability; this is what §Search gets from each:

| Capability | What §Search gets |
|---|---|
| Filter **and** order by date | newest-first, date-bounded, one query |
| Filter by date, no ordering | a date-bounded candidate set; rank in the agent |
| Neither | relevance order only; recover per-hit dates and rank in the agent |

A store that cannot order by date does not fail the recency-shaped trigger — it costs more to serve.
Most stores in the table return a modification date per hit for free, so the agent can rank the
candidates it received without an extra call; what it cannot do is ask the store for the newest
material it has never seen. `ghe`/`gitlab` is the exception: `src search` hits carry no date, so
recovering one costs a separate `git log -1` call — pay it only for hits that already cleared the
relevance bar, not for the full result set. Where ordering is unavailable, say the ranking was done
over the hits returned rather than implying the store reported its newest documents.

**A store kind with no search primitive is a gap, not an improvisation.** `public-web` has no
discovery call — `WebFetch` opens a URL the agent already holds. Record the gap per §On no match;
never substitute a different tool to fake a search the store does not offer.

**Search scope is a call-shape fact here, an authorization decision there.** A rooted search is the
native call shape for these tools: SharePoint's `search` takes a `<drive_id>`, and Box's takes
`--ancestor-folder-ids`. Tenant-wide is the form that costs extra — SharePoint's is a raw Graph
`/search/query` POST with no script subcommand. Which of the two a session is *allowed* to run is not
this table's call: `routing-protocol.md` §Search owns it, and the reasoning is
`references/external-retrieval-search-design.md` § Why the search-scope guard is a default,
not a prohibition.

## Degradation Patterns

When a tool is missing, the agent should:

1. **State the degradation explicitly** in the response. Example:
   > "I can't query the program Confluence directly — the `<domain>-confluence` MCP isn't loaded. For the pages you're asking about, see `knowledge/program/confluence-index.md` — it has space keys and page IDs you can look up manually."

2. **Offer the fallback immediately** without waiting for the user to ask. The fallback is usually a URL or a knowledge-file pointer.

3. **Always surface the install path.** Name the missing skill/MCP, provide the install command (e.g., `claude plugin install <skill>@<marketplace>`), and offer to walk the user through install. This applies even to one-off questions — Hive users span all experience levels, and explicit flagging is how newer operators discover tooling that experienced operators already have. Name the actual `<marketplace>` the skill lives in rather than assuming a default — different orgs and Hives may register skills in different marketplaces.

   See `PROTOCOL/workflows.md` §"Cross-Cutting Discipline → Missing skill transparency" for the full template. [learned: 2026-04-19]

## The Three Tiers (for README documentation)

Child Hive READMEs should document three install tiers so new users can pick the level of integration appropriate to their work:

| Tier | Install | What works |
|------|---------|-----------|
| **Read-only** | None (plain Claude Code) | Agent reads `knowledge/` and `PROTOCOL/`, answers with citations, writes contributions to `_inbox/` |
| **Connected** | the standard tool set (jira-cli, confluence-cli, slack-cli, chrome-auth) | Agent queries live Jira/Confluence/Slack; surfaces current state |
| **Full** | + domain MCPs (e.g., a program-specific `<domain>-confluence`, or `mcp-atlassian` for combined access) | Agent queries all relevant internal + external systems |

Each Hive's README may rename tiers or adjust the contents, but the tiered-install pattern is standard so users have a consistent mental model across Hives.

## Extension

Hives with domain-specific tools (e.g., `platformctl`, `sim-engine`, `simclient`) add rows to the routing table in their `PROTOCOL/agent-definition.md`. The format mirrors the standard set above: Tool → Purpose → Fallback.
