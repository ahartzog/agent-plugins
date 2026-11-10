# Operate Mode - Load the Operating Protocol

Activated by `/second-brain operate` or by a domain agent's bootstrap step. Loads the operating protocol into the session.

**This file contains only what a session needs to execute.** Rationale lives in `DESIGN-GOALS.md` §3 and `references/learning-loops.md`.

## Step 1: Load the protocol

Read one file, relative to this skill's base directory:

`protocol/operating-protocol.md`

That is the whole in-session protocol. Do not read the other files in `protocol/` now. `knowledge-schema.md` and `link-authoring.md` are read when you create a file or write a link. `triage-policy.md` and `learning-loops.md` are vocabulary for wrap, audit, and custodian runs.

The operating protocol is authoritative. Where it conflicts with something restated in a `CLAUDE.md`, an agent file, or a CONTRIBUTING file, the protocol wins and the local restatement is stale. One exception, stated in the protocol itself: a folder's own `CLAUDE.md` may set a stricter rule for that folder, and the stricter rule holds.

## Step 2: Establish the contribution setting

Read `auto_contribute` from the **invoking agent definition's** YAML frontmatter (not the hub's, not this skill's). If absent, treat it as `false`. The protocol's section "What needs a yes first" says what each setting means.

A specialist spawned as a subagent reads its own definition and its own frontmatter. Settings are never inherited from the invoking agent.

If invoked with no agent context, treat the setting as `false`.

## Step 3: Local files

Locate these relative to the invoking agent definition's own file path (its domain folder, then the hub root above it), not the session's working directory. Read them when present and not already in context; skip silently when absent. A missing hub is not an error and never a reason to offer to create one.

| File | Why |
|---|---|
| `CLAUDE.md` at the hub root and in the domain folder | Routing, shared context, and any stricter folder rule |
| `CONTRIBUTING.md` or `* Contributing.md` | Multi-maintainer conventions, where a hub has them |

## Step 4: Proceed

Do not announce the load. Go straight to what the session is about. If the owner asks whether the protocol is loaded, answer in one line: the protocol's `last_updated` date and the `auto_contribute` value.

## If the skill is unavailable

There is no copy of the protocol outside this skill. The agent definition's bootstrap block carries the fallback, because this file is unreadable when the skill is missing:

1. Say once, plainly, that the protocol is not loaded, and give the install pointer from the hub or domain `CLAUDE.md`.
2. Answer from the knowledge files as normal.
3. Write only what the owner explicitly asks to have written down (a note, a log entry they dictate). Surface everything else as plain text for the owner to place.
