---
type: protocol
description: "Which knowledge changes an agent writes directly and which wait for the owner's yes, plus the tag vocabulary wrap and audit use in their ledgers. Demand-loaded; the in-session rule lives in operating-protocol.md"
last_updated: 2026-11-09
---

# Triage Policy

Since 3.0.0 the in-session rule is the section "What needs a yes first" in `protocol/operating-protocol.md`. Operate mode does not load this file. Wrap and audit read it for the tag vocabulary they use in ledgers and reports. Where this file and the operating protocol differ, the operating protocol wins.

## Two classes

| Class | What is in it | What the agent does |
|---|---|---|
| **Write** | New facts, status updates, log entries, factual corrections, decisions the owner stated, links between files | Writes in the same turn and reports it with a `Saved:` line |
| **Ask first** | Unresolved conflicts; deleting or restructuring content beyond the fact being changed; changes to agent definitions, the protocol, hooks, or workflows; anything in an external system | Proposes it as a numbered item in the reply and applies it on a yes |

## The `auto_contribute` setting

Each agent declares `auto_contribute` in its own frontmatter. It moves the Write class only.

| Setting | Behavior |
|---|---|
| `true` | Writes the Write class directly |
| `false` (default for a new agent) | A log entry the owner dictates still goes straight in. Everything else in the Write class is proposed as one numbered list and written on approval |

The Ask-first class waits for a yes under either setting.

## Tag vocabulary

Wrap ledgers, audit reports, and custodian telemetry label contributions with these tags. Agents do not need to tag anything during a session.

| Tag | Meaning | Class |
|---|---|---|
| `[correction]` | A fact the owner said was wrong | Write |
| `[link]` `[person]` `[tracker]` | A new document, person, or tool | Write |
| `[status]` | A status or timeline update | Write |
| `[discovery]` | A workaround, quirk, or limitation | Write |
| `[edge]` | A link between two knowledge files | Write (changed in 3.0.0: a link is additive and easy to remove) |
| `[contradiction]` | New information conflicts with a file and the right value is unclear | Ask first |
| `[architecture]` `[process]` | Restructuring content, or changing how work is done | Ask first |
| `[custodian]` | A new or changed custodian check | Ask first |
| `[agent-revision]` | A change to an agent definition | Ask first |

## How to ask

Put proposals in the reply the owner is already reading, as numbered items they can answer by number. One line of what would change and where, one line of why. Batch them; do not raise them one at a time, and do not queue them somewhere the owner has to go and look.

## Changing this policy

If an owner keeps approving a category that is in Ask first, or keeps rejecting one that is in Write, say so and propose moving it for that hub. The move itself is an Ask-first change.
