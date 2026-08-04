# Authoring a Workflow Extension

How to add a named, invokable workflow to a single Hive without changing upstream protocol.

Read this when a Hive needs a recurring interaction that the seven upstream workflows
(`protocol/workflows.md`) don't name — a report it produces every week, a review it runs
every release, an intake process specific to its domain. The result is a file under the
path declared by `extensions.workflows` in `hive.yml`, merged into the dispatch table by
`references/mode-operate.md` § Merge Extensions.

Machine-readable frontmatter contract: `assets/workflow-extension.schema.json`.
Starting point: `assets/workflow-extension-template.md`.

---

## When You Need One (and When You Don't)

| Situation | Do this |
|---|---|
| The behavior you want is a recurring, *nameable* interaction the user will ask for by name | Author a workflow extension |
| You just need the agent to know a fact, a process, or a set of steps | Write a `knowledge/` file — no extension |
| An upstream workflow already covers it but routes badly | Fix the upstream workflow via an upstream Apiary PR — don't shadow it locally |
| You want to *remove* or *replace* upstream behavior | Not possible. Extensions are additive only (plugin-root `DESIGN-GOALS.md` principle 3) |

The test: **would a user type it?** "Run our 5-15." "Do a release review." If the phrase is
something a person says to start a task, it wants a dispatch-table row. If it's something the
agent needs to *know* mid-task, it's knowledge.

---

## File Layout

One file per workflow, named after the workflow, under the declared extension directory:

```
PROTOCOL/
└── extensions/
    └── workflows/
        ├── standup.md      # workflow: standup
        └── release-review.md
```

`extensions.workflows` in `hive.yml` may point at a directory (all `*.md` inside are loaded)
or a single file. A directory is preferred — it scales without touching `hive.yml` again.

Because these live under `PROTOCOL/`, they are subject to the PROTOCOL size budget
(< 300 lines, `protocol/design-goals.md` § 6). A workflow extension that needs more than that is
carrying mechanics it should be delegating — see § Routing vs. Mechanics.

---

## Required Frontmatter

```yaml
---
layer: PROTOCOL
type: workflow-extension
workflow: {WORKFLOW_NAME}          # the dispatch-table name; must match the filename stem
description: "{ONE_LINE_SUMMARY}"  # what it does + what it delegates to
last_updated: YYYY-MM-DD
codeowners: [{GHE_HANDLE}]
---
```

`workflow` is the identity field — it's the name that lands in the dispatch table and the
name the agent reports when it routes. Keep it kebab-case, short, and typeable.

---

## The Dispatch-Table Row

Every extension must declare exactly one dispatch-table row, in a `## Dispatch Table Addition`
section, using the same two-column shape as the upstream table in `mode-operate.md` § Detect and Execute Workflow:

```markdown
## Dispatch Table Addition

| Input Pattern | Workflow |
|---|---|
| `standup`, "daily standup", "post the standup", "what do I say at standup" | **Standup** (this extension) |
```

Rules:

- **List real phrasings, not a category.** `"weekly status report"` routes; `"status stuff"` does not.
  Include the literal token a user would type (`5-15`, `standup`), common spoken variants, and at
  least one question-shaped form.
- **Mark it as an extension** — `(this extension)` — so a reader of the merged table can tell
  Hive-local rows from upstream ones.
- **One row per file.** Two workflows means two files.

### Disambiguation is mandatory

The upstream table already claims broad patterns — Ask is the default for *anything*
unmatched, Status owns "current state," Brief owns "weekly summary / digest / what did we
learn." A new row that overlaps one of those will lose, win by accident, or flip between runs.

State the boundary explicitly, in prose, immediately under the row:

> **Disambiguation from Brief.** Brief is the Hive's *internal* learning digest (what the Hive
> learned this week). Standup is an *external* team artifact (what I personally did, posted to a
> channel). "What did we learn / digest" → Brief. "Standup / what do I say" → this workflow.

If you cannot write that paragraph, the workflow isn't distinct enough to need a row.

---

## Routing vs. Mechanics — the Split That Keeps It Alive

**A workflow extension holds routing and interaction behavior. It delegates deep mechanics to a
`knowledge/` file.**

| Belongs in the extension (PROTOCOL) | Belongs in `knowledge/` |
|---|---|
| Input patterns and disambiguation | Query strings, JQL, channel lists, API calls |
| Questions to ask before doing work, and in what order | Output format recipes, templates, tooling steps |
| Which variant/profile applies to whom | Content rules, thresholds, worked detail |
| Preconditions and refusals ("don't proceed until X") | Anything that changes when a system changes |

Why the split matters: mechanics change often and are owned by whoever runs the system;
routing changes rarely and is owned by CODEOWNERS. Putting both in the extension means every
tweak to a Jira filter needs a CODEOWNERS PR — friction that gets routed around (Goal 5). Putting
routing in `knowledge/` means Parliament can quietly rewrite your dispatch behavior.

**One source of truth each — never both.** The extension points at the knowledge file; it does
not restate its contents. A duplicated step list is a guaranteed drift site (Goal 1).

> The mechanics of *how* the report is generated — the data sources, the queries, the output
> recipe — live in **`knowledge/{domain}/{workflow}-mechanics.md`**. This extension does not
> duplicate them. Its one job is to establish *who* and *what* before generation begins.

---

## Optional: Variant Profiles

If one workflow serves several audiences with genuinely different shapes (different owners,
sources, or output structure), declare **profiles** rather than forcing one path. Specify the
profile you actually know; leave the rest as honest stubs plus a **generic fallback profile**
that asks the user instead of guessing.

Then grow the stubs: first time a stub runs, capture what you learned about that variant as a
`[process]` inbox contribution proposing a full profile. Parliament folds it back in. This is the
contribution flywheel (Goal 5) applied to the extension itself.

Do not silently inherit the specified profile's data sources for an unprofiled variant — that
produces a confidently wrong result, the worst failure mode in the Hive.

---

## Governance

Workflow extensions are **PROTOCOL files**. Changes go through a **CODEOWNERS PR** on the Hive
repo — *not* the inbox, *not* Parliament. Parliament owns `knowledge/`; humans own `PROTOCOL/`
(`protocol/design-goals.md` § 4 Collective Ownership, § 8 Upstream Governance).

A session that discovers the extension is wrong should still file a `[meta]` or `[process]` inbox
entry describing the gap — that's the signal. The fix itself is a PR.

Extensions are **Hive-local and additive**. If the workflow would be useful to more than one
Hive, that's a signal it belongs upstream in `protocol/workflows.md` — open an upstream Apiary PR
instead. Ask: *is this domain-specific, or did I just find a hole in the upstream protocol?*

---

## Minimal Worked Example

`PROTOCOL/extensions/workflows/standup.md`:

```markdown
---
layer: PROTOCOL
type: workflow-extension
workflow: standup
description: "Invokable, author-aware entry point for the team's daily standup post. Confirms author + scope, then delegates gathering mechanics to knowledge/team/standup-mechanics.md."
last_updated: 2026-07-27
codeowners: [example-handle]
---

# Workflow Extension — Standup

Merged into the upstream dispatch table by Apiary operate mode (Step 4). This makes the
standup a first-class, named workflow — invoke it directly instead of hoping the agent
finds the knowledge doc.

## Dispatch Table Addition

| Input Pattern | Workflow |
|---|---|
| `standup`, "daily standup", "post the standup", "what do I say at standup" | **Standup** (this extension) |

**Disambiguation from Brief and Status.** Brief is the Hive's *internal* learning digest
(what the Hive learned this week). Status is a current-state briefing on work items.
Standup is an *external* per-person artifact posted to a team channel.
"Digest / what did we learn" → Brief. "What's blocked on X" → Status.
"Standup / what do I say" → this workflow.

## What This Workflow Does

The mechanics — which channels and boards to read, the post format, the length limits —
live in **`knowledge/team/standup-mechanics.md`**. This extension does not duplicate them.
Its one job is to pin down *who* is posting and *what scope* they own before gathering starts.

## Step 0: Author + Scope (REQUIRED — before anything else)

Ask two questions and wait for answers. Do not start gathering until both are answered.

1. **Who are you?** (GHE handle — sets attribution and which boards are yours)
2. **What scope?** (team / sub-team / personal — sets which sources are in play)

If the user already stated both up front ("do my backend standup"), skip the questions and
route directly — don't re-ask what you were told.

Then run `knowledge/team/standup-mechanics.md` in full.

## Governance

This is a PROTOCOL file. Changes go via CODEOWNERS PR, not the inbox. Routing and the
author/scope gate live here; gathering mechanics live in the knowledge file — one source of
truth each, no duplication.
```

---

## Pre-PR Checklist

- [ ] Filename stem matches the `workflow:` frontmatter value
- [ ] Frontmatter validates against `assets/workflow-extension.schema.json` — extract the
      block between the `---` fences first:
      `awk '/^---$/{n++;next} n==1' <file> | yq -o json | ajv validate -s workflow-extension.schema.json`
- [ ] Exactly one `## Dispatch Table Addition` row, with literal user phrasings
- [ ] A disambiguation paragraph naming the upstream workflow(s) it could be confused with
- [ ] Mechanics live in a `knowledge/` file and are referenced, not restated
- [ ] File is under the 300-line PROTOCOL budget
- [ ] `hive.yml` `extensions.workflows` points at the containing directory
- [ ] Opened as a CODEOWNERS PR on the Hive repo, not an inbox contribution
- [ ] `/apiary audit` passes Step 5 (Extension Validity) with no findings
