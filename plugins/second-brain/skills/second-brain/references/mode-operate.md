# Operate Mode — Load the Operating Protocol

Activated by `/second-brain operate` or by a domain agent's bootstrap step. Loads the universal operating protocol into the session.

**This file contains only what a session needs to execute.** Rationale lives in `DESIGN-GOALS.md` §3 and `references/learning-loops.md`.

## Step 1: Load the Protocol Layer

Read all three, in order. Paths are relative to this skill's base directory:

1. `protocol/learning-loops.md` — the five loops, the Self-Awareness Protocol, and the `auto_contribute` contribution gate
2. `protocol/triage-policy.md` — which contribution categories are auto-eligible vs always-prompt
3. `protocol/knowledge-schema.md` — required frontmatter, type semantics, decay thresholds, inline annotations

These are authoritative. Where they conflict with anything restated in a `CLAUDE.md`, agent file, or CONTRIBUTING file, **the protocol wins** — a local restatement is a stale snapshot.

## Step 2: Establish the Contribution Setting

Read `auto_contribute` from the **invoking agent definition's** YAML frontmatter (not the hub's, not this skill's). If absent, default to `false`.

- `false` → surface every proposed knowledge change for approval before writing
- `true` → write auto-eligible changes directly; report what changed at session end

Regardless of the setting, these always prompt: contradictions (Loop D), custodian evolution (Loop C), process/agent-definition changes (Loop E), architecture/process claims, and deleting or substantially rewriting existing content.

**Subagents resolve their own gate.** A specialist spawned via the `Agent` tool reads its own definition file, re-runs this bootstrap, and reads its own frontmatter. Gates are never inherited from the invoking agent — an `auto_contribute: false` specialist stays propose-first even when spawned by a `true` lead.

If invoked standalone (no agent context), say no agent frontmatter was found and assume `false`.

## Step 3: Load Local Extensions, If Any

Locate these **relative to the invoking agent definition's own file path** — its domain folder, then the hub root above it — not the session's working directory, which is unrelated on shim and file-path invocations. If no agent context exists, fall back to SKILL.md hub discovery from the cwd. A missing hub is not an error here: skip silently and proceed — never respond by offering to create or adopt one (operate is plumbing).

Read these when present; skip silently when not:

| File | Role |
|---|---|
| `CLAUDE.md` at the hub or domain root | Routing table, shared context, ambient guardrails, write-zone ownership |
| `CONTRIBUTING.md` or `* Contributing.md` | Multi-maintainer conventions: ownership zones, edit rules, conflict handling |
| `custodian-workflow.md` | The hub's accumulated Loop C check list |

**Precedence:** protocol (floor) → agent definition (domain behavior) → `CLAUDE.md` (local additions). A local file may add a stricter or domain-specific rule. If one *contradicts* the protocol, follow the protocol and tell the user that file looks stale — a Loop C signal.

## Step 4: Confirm and Proceed

Report compactly, then continue with whatever the session was about:

```
Protocol loaded: 5 loops, auto_contribute={true|false}, schema v{date}.
Local extensions: {files read, or "none"}.
```

Keep it to those lines. Operate mode is plumbing — it should not narrate.

## If the Skill Is Unavailable

There is no fallback protocol; the loops, triage, and schema exist only here. An agent without them has no operating protocol at all — not a reduced one. The live copy of this contract is the agent definition's bootstrap block (this file is unreadable when the skill is missing). It requires:

1. Say so once, plainly, and name the install pointer from the hub or domain `CLAUDE.md` Dependencies section (fallback: the plugin README's install commands).
2. **Read freely, write nothing.** Answer from the knowledge files as normal — retrieval needs no protocol.
3. Surface findings as plain text for the user to place.

Do not reconstruct loop routing, target files, or triage rules from memory. A wrong write corrupts the knowledge base silently, which is what the protocol exists to prevent.
