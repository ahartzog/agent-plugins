---
type: protocol
description: "Rules for routing knowledge contributions: auto-apply vs prompt-user, by contribution category and auto_contribute setting"
last_updated: 2026-05-22
---

# Triage Policy

This file governs how learning loop contributions are routed during a session. The agent's `auto_contribute` frontmatter setting determines baseline behavior; this policy defines category-level overrides that always require prompting regardless.

---

## Contribution Behavior

Each agent declares `auto_contribute` in its own YAML frontmatter:

| Setting | Behavior | Best For |
|---|---|---|
| `false` | Surface every proposed change to the user. Wait for approval before writing. | New setups, sensitive domains, early trust-building |
| `true` | Write auto-eligible changes directly to knowledge files. Report what changed at session end. | Mature agents where the user trusts the flywheel |

Default is `false`. Users switch to `true` once the agent has demonstrated good judgment — this is what makes the system compound.

---

## Contribution Categories

Each knowledge contribution carries an implicit category based on its nature. The category determines whether it is auto-eligible (written directly when `auto_contribute: true`) or always-prompt (requires user approval regardless of setting).

| Tag | Category | Auto-eligible? | Path when `false` | Path when `true` |
|---|---|---|---|---|
| `[correction]` | Factual correction (Loop A) | Yes | Prompt with proposed rule text + target | Apply to agent rules + annotate |
| `[link]` | New document/resource link | Yes | Prompt with entry + target file | Apply to knowledge file |
| `[person]` | New person/role | Yes | Prompt with entry + target file | Apply to knowledge file |
| `[tracker]` | New tracker/channel/tool | Yes | Prompt with entry + target file | Apply to knowledge file |
| `[status]` | Status update | Yes | Prompt with entry + target file | Apply to knowledge file |
| `[discovery]` | Workaround/quirk/gap (Loop B) | Yes | Prompt with content + target file | Apply to knowledge file |
| `[edge]` | Connection between two knowledge files (Loop B § Connections) | No | Prompt with source, target, and the traversal that found it | Prompt — new category, no safety data yet |
| `[architecture]` | Architectural claim | No | Prompt — strategic implications | Prompt — strategic implications |
| `[process]` | Process/principle change | No | Prompt — affects how work is done | Prompt — affects how work is done |
| `[contradiction]` | Contradicts existing fact (Loop D) | No | Prompt — judgment call | Prompt — judgment call |
| `[custodian]` | New custodian check (Loop C) | No | Prompt — structural change | Prompt — structural change |
| `[agent-revision]` | Agent-definition revision (Loop E) | No | Prompt — structural change to enforcement | Prompt — structural change to enforcement |

**Expected split:** ~70-80% of contributions in a typical session are auto-eligible categories. The remaining 20-30% require user judgment.

---

## Category Detection

Agents do not explicitly tag contributions. Instead, the agent evaluates the nature of the knowledge being written and applies the appropriate routing:

1. **Is this correcting something the user said was wrong?** → `[correction]` (Loop A)
2. **Does this contradict an existing knowledge file entry?** → `[contradiction]` (Loop D)
3. **Is this a new link, person, or tracker?** → `[link]`/`[person]`/`[tracker]`
4. **Is this a relationship between two knowledge files rather than a new fact?** → `[edge]`.
   But if both files claim authority over the same content, it is `[architecture]` instead — the fix
   is consolidation, not a link.
5. **Is this a status/timeline update?** → `[status]`
6. **Is this a workaround, tool limitation, or operational discovery?** → `[discovery]`
7. **Does this describe architecture, system design, or strategic direction?** → `[architecture]`
8. **Does this change a process, workflow, or principle?** → `[process]`
9. **Is this suggesting a new custodian check?** → `[custodian]`
10. **Does this propose revising the agent's own instructions (Rules, How-to-Advise, Bootstrapping)?** → `[agent-revision]` (Loop E)

When ambiguous, prefer the more conservative category (prompt over auto).

---

## Prompt Format

When prompting the user (either because `auto_contribute` is `false` or the category requires it), use this format:

```
[Loop {A|B|C|D|E}] Proposed knowledge update:
  Category: {category}
  Target: {file path}
  Content: {the proposed addition or change, 1-3 lines}
  Apply? (y/n/edit)
```

If the user says `y`, apply immediately. If `n`, discard (but note the rejection — repeated rejections of a category are a signal to recalibrate). If `edit`, let the user modify before applying.

---

## Session-End Report

When `auto_contribute: true`, the agent MUST report all changes made during the session before concluding:

```
Knowledge updates this session:
  - [correction] Added rule to financial-advisor.md: "Re-verify live FMV before sizing any exercise"
  - [link] Added insurance portal URL to reference-library.md
  - [status] Updated benefits.md: Esprea credit activated Apr 1
```

When `auto_contribute: false`, this report is unnecessary since the user approved each change individually.

---

## Policy Evolution (Loop C)

This policy can evolve based on observed patterns:

- If a user consistently approves a category that is currently always-prompt, that's a signal the category could be reclassified as auto-eligible. The custodian should surface this observation.
- If a user consistently rejects auto-eligible contributions in a specific category, that's a signal to reclassify as always-prompt for that hub.
- Policy changes are always proposed via Loop C (custodian self-improvement) and require user approval.

Track approval/rejection patterns in `_reports/loop-health.json` to support data-driven policy evolution.
