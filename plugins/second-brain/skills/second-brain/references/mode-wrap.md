# Wrap Mode — Session-End Verification

Diff what this session learned against the hub's knowledge files, close the gaps, and log telemetry. This is the one check nothing else can perform: audits and custodians see files; wrap sees the session.

Wrap is the **manual verification** of the contribution reflex, not a replacement for it. The protocol deliberately contributes after each task rather than at session end (sessions end unpredictably). Wrap is how the user confirms that actually happened.

## Architecture — script, then subagent, then judgment

Three work stages plus a gate and a ledger, cheapest first. Most of the work is mechanical and does not belong on an expensive model or in the main context.

| Stage | Runs on | Job |
|---|---|---|
| 1. Extract | `scripts/extract_session.py` | Parse the session transcript into a digest of substantive turns |
| 2. Evaluate | Sonnet subagent | Read each turn, identify candidate knowledge, check whether it landed in the hub, return three buckets |
| 3. Persist | Inline, this conversation | Judge what's worth keeping, resolve ownership, write per `auto_contribute` |
| 4. Loop E gate | Inline, this conversation | Run the four retrospection questions against the session |
| 5. Report | Inline, this conversation | Ledger + telemetry append + gate marker |

**Why the transcript and not recall.** Claude Code writes every turn to `~/.claude/projects/<slug>/<session-id>.jsonl`. That file survives context compaction; the model's memory of the session does not. Asking yourself "what did I learn?" is the same operation that already failed if the contribution reflex didn't fire — so the transcript is the input, not a cross-check.

**Why a subagent for stage 2.** Stages 1–2 are diffing, not judgment: scan turns, grep knowledge files, bucket the results. Delegating keeps the bulk digest and the file reads out of the main context — the inline turn receives only the buckets. This is the one sanctioned delegation in wrap: the subagent gets the transcript digest as input, so it is not being asked to "see" a session it wasn't part of.

## Hard constraints

1. **Judgment stays inline.** Stages 3–5 run in the invoking conversation with the user present. Deciding what deserves to persist, which file owns it, and whether it contradicts something is judgment — only the harvest and diff are delegated, and only with the digest as input.
2. **Fresh-session refusal is mechanical first.** The extractor exits non-zero when there is no transcript (2) or no substantive user turns (3). On either, report that wrap needs the session that did the work and stop. Write nothing. Never fabricate a ledger.
3. **Digest sanity check.** Before delegating, confirm the digest is *this* conversation — its recent turns must match what you know this session did. A stale or mismatched digest (wrong session picked up) fails the same way a fabricated ledger would; on mismatch, fall back to inline harvest from the live conversation and say so.
4. **Never defer to the wrap.** The contribution reflex stays primary. If knowledge surfaces mid-session, contribute then — do not save it for a wrap that may never run.
5. **The audit safety constraints apply** (`mode-audit.md`): never delete, never edit inside code fences, no absence claims from sampled scans, never silently overwrite (`[superseded:]` with diff shown).

## Procedure

Run hub discovery first (per SKILL.md) — the mode needs to know which directory owns the knowledge files before it can say a fact is missing *from* somewhere.

### Stage 1 — Extract the digest

```bash
python3 "{skill_base}/scripts/extract_session.py"
```

Resolve `{skill_base}` to **this skill's base directory** (announced when the skill loads) — do not rely on `${CLAUDE_PLUGIN_ROOT}`, which is not exported to the Bash tool's environment. If the command fails with a path error (stderr shows the file can't be opened), the script path is wrong — fix it; that is **not** a "no transcript" result.

Run it **without** `--cwd` first: the script defaults to the session's actual working directory, which is where Claude Code keyed this session's transcript. Pass `--cwd {hub_path}` only if the default finds no transcript (e.g. wrap invoked from a different directory than the work ran in) — and then apply constraint 3 with extra suspicion, since the newest transcript for another directory may be a different conversation.

Emits user turns and assistant prose with tool traffic, thinking blocks, sidechain agents, and harness-injected reminders stripped. A full working session is typically a few thousand tokens. Flags: `--session-id <uuid>` to target a specific session, `--json` for structured output, `--max-chars` to bound long turns.

Honor a non-zero exit per constraint 2 — do not proceed to stage 2. If `python3` is unavailable, fall back to inline harvest from the live conversation (the pre-2.0 wrap path) and note the degraded input.

### Stage 2 — Delegate harvest + diff to a subagent

Dispatch one subagent (`model: sonnet`) with the digest and the hub path. Its job is to evaluate every turn against the knowledge files and return buckets — nothing else. Give it read-only tools; it proposes, it does not write.

Read `protocol/triage-policy.md` (relative to this skill's base directory) yourself first — the subagent has no skill context and can't resolve that path on its own. Pass its content inline.

Prompt it with:

- The digest from stage 1
- The hub path, its `index.md` files, and the agent routing table
- The triage policy content you just read, for tagging
- This instruction: *for each turn, ask whether it produced knowledge a future session would need — a fact, correction, decision, resolved research, or process friction. For each candidate, read the knowledge file that would own it and determine whether it is already there.*
- Report a candidate it is unsure about rather than dropping it — a false positive costs one line of the user's attention; a false negative is the failure the mode exists to prevent.

Require this back:

```json
{
  "captured":  [{"item": "", "file": "", "evidence": ""}],
  "missing":   [{"item": "", "target_file": "", "triage_tag": "", "turn": 0}],
  "ambiguous": [{"item": "", "file": "", "problem": "partial|stale|wrong-file"}]
}
```

| Bucket | Meaning |
|---|---|
| **Captured** | Present with a `[learned:]`/`[superseded:]` annotation dated today, or content visibly updated |
| **Missing** | Not in any knowledge file |
| **Ambiguous** | Present but partial, stale, or in the wrong file |

Ambiguous is the bucket that earns its keep: a fact written to the wrong domain file, or a status updated without superseding the old value, reads as captured but isn't retrievable.

### Stage 3 — Judge and persist, inline

The subagent found candidates. Deciding which deserve to persist is yours:

1. **Filter.** Session mechanics, dead ends, and facts already recorded elsewhere are not knowledge. A durable fact, a correction the user made, or a decision with a rationale is.
2. **Confirm ownership.** The subagent proposes a target file; verify it against the routing table. A fact in the wrong domain file is retrievable by nobody.
3. **Write Missing items** per the owning agent's `auto_contribute` frontmatter — `true`: write directly and report; `false` or absent: propose and wait. Contradictions (Loop D) and process changes (Loop E) always prompt regardless.
4. **Resolve Ambiguous items** in place — move, complete, or supersede.
5. **Update the domain `index.md`** if files were added or repurposed.

### Stage 4 — Loop E gate

Answer the four retrospection questions against this session:

1. Did the agent's instructions produce a good answer, or were they worked around?
2. Did the user correct approach, tone, or framing — not just facts?
3. Did the session surface a judgment frame, tradeoff, or heuristic missing from the agent file?
4. Was a prescribed step skipped, or a rule followed that felt wrong?

Any yes → propose an agent-file revision (always prompts; prefer principles over procedures, attach the worked example).

### Stage 5 — Report + telemetry

Output the ledger: three buckets, ranked within bucket, with counts — numbers carry the weight, no editorializing.

```
Wrap — {N} candidates from {M} turns
  Captured (n):  {one line each}
  Missing (n):   {one line each, with target file and action taken}
  Ambiguous (n): {one line each, with what was wrong and how it was resolved}
```

Append to `_reports/loop-health.json` (create the file as a JSON array if missing):

```json
{
  "date": "YYYY-MM-DD",
  "run_type": "session-end",
  "wrap_captured": 0,
  "wrap_missing": 0,
  "wrap_ambiguous": 0,
  "discoveries_written": 0,
  "corrections_propagated": 0,
  "process_revisions_proposed": 0,
  "note": "domains touched; one-line session summary"
}
```

Then touch the gate marker: `touch .session-gate` at the hub root. If `.session-gate` is not gitignored, offer to add it — the marker is machine state, never content.

## First run in a hub

On the first wrap in a hub, offer a two-line alias shim so the ritual costs two keystrokes — a skill named for the hub's preference (`/wrap` is the reference choice) whose entire body is: invoke the `second-brain` skill with args `wrap`. The alias is convenience; this mode is the single source of truth.

## Telemetry signal

`wrap_missing` trending toward zero across sessions means the continuous reflex is working. A rising trend is a Loop E finding about the agents' contribution discipline — fix the agents, not the wrap; surface it as a `/second-brain improve` candidate for the agent whose items keep getting missed.

## Wrap's own Loop C

When wrap misses an item the user catches — or flags a phantom that was never real knowledge — fix it, identify the CLASS of miss, and propose the fix at the right layer (always prompts): a universal harvest gap → this mode's stage 2 instruction (an upstream skill change); a hub-specific pattern → the hub's `custodian-workflow.md` checklist.

## Hook forward-contract

`.session-gate` is a timestamp marker. If loop-health telemetry shows active sessions where wrap never ran despite knowledge activity, escalate the advisory Stop hook (`references/enforcement-hooks.md` recipe 2, including its conditional self-clearing variant) to block once per session when knowledge files were touched and the marker is stale; wrap's stage 5 clears it. Keep the hook conditional — an unconditional blocking Stop hook gets the whole system disabled.
