# Pre-Push Sentinel — Hook-Driven Override Flow

Use this reference when the `pre-push` git hook (installed by `mode-operate.md` Step 0 at `{HIVE_ROOT}/.githooks/pre-push`) blocks a push. The hook reads patterns from `sentinel-patterns.json` and exits non-zero on any uncovered match. **The hook is the gate** — protocol prose alone cannot enforce this; the hook can.

This file is the editorial runbook the agent follows *after* the hook fires: diagnose each match, redact (the common case) or — rarely — record a user-approved override. It is referenced from:

- `references/mode-operate.md` "Push Procedure" (session contribute push)
- `protocol/security-policy.md` § Defensive layers (Layer 0)
- `protocol/sensitive-data-patterns.md` § Disposition
- the generated hook's block message (produced by `assets/generate-hook.sh`)

The runbook lives here rather than inline in `mode-operate.md` because it is only exercised when the hook blocks — it is not part of the normal operate-mode happy path, and keeping it separate keeps the operate-mode procedure scannable.

---

When `git push` exits non-zero with the hook's "Pre-push Sentinel block" message on stderr, the agent diagnoses the match and acts. Do not retry blindly. Do not bypass with `--no-verify`. Do not modify the patterns file to make the match disappear.

## Step 1: read the matched content in context

Open each flagged file and look at each line the hook reported. The agent has context the regex doesn't — what the file is for, what the surrounding paragraphs say, where the content came from. Use it.

## Step 2: classify each match

For each match the hook reported, decide which case applies:

**Case A — real sensitive content (the common case).** The agent wrote the file and recognizes that it included a credential, SSN, phone number, etc. Almost every match falls here. Acknowledge the mistake plainly to the user, redact in place, retry the push:

> "I see I included a hardcoded password literal in {file} on line {N}. I'll redact it and reference the canonical source instead, then retry the push."

Then perform the redaction. Good redactions preserve operational intent — replace `Password: hunter2` with `Password: see Confluence pageId 393053557`, not just delete the line. Retry the push; the hook re-runs and (typically) clears.

No `AskUserQuestion`, no override. Redaction is the agent's job and the user expects the agent to do it.

**Case B — false positive (the rare case).** After looking at the matched content, the agent has a specific reason to believe the regex is wrong: e.g., the matched value is a placeholder (`<your-token-here>`), a documentation example, or a value that coincidentally matches the pattern but is not actually sensitive. The burden of proof is on the agent — it must be able to articulate *why* it isn't sensitive.

Surface the diagnosis to the user and ask via `AskUserQuestion`:

> "Sentinel flagged {pattern} in {file} at line {N}: `{excerpt}`. Looking at it, I think this is a false positive because {specific reason}. Do you want me to record an override and proceed with the push?"

Only on an explicit "yes" → record the override (procedure below) and retry. On "no" or any answer that asks for redaction → fall back to Case A.

**Case C — cannot redact (very rare).** The flagged content is intrinsic to the contribution and has no canonical source to point at. Tell the user plainly and stop:

> "Sentinel flagged {pattern} in {file} on line {N}, and the content is intrinsic to the contribution — I can't redact it without losing the point of the file, and I don't think this is a false positive. Stopping here. Let me know how you'd like to proceed."

Do not push. Do not delete or modify the file. The user decides next steps in a follow-up turn.

## Anti-patterns

- Don't reach for the override every time the hook fires. Override is the exception — Case A (redact) is the default.
- Don't propose override as a menu option to the user when you haven't already diagnosed the match yourself. The user shouldn't have to do the agent's analysis.
- Don't redact silently. Tell the user what was matched and what you replaced it with — they need to be able to spot a bad redaction.
- Don't retry the push without addressing the match. The hook re-runs from scratch on every push and will block again.

## Recording an override (Case B only, after explicit user approval)

1. Read the user's git identity: `git config user.name` (fall back to `$USER`).
2. Amend the inbox file's frontmatter with:

   ```yaml
   sentinel_override:
     reviewed_by: <git-user>
     reviewed_at: <ISO-8601 UTC>
     patterns: [<every pattern name reported by the hook for this file>]
     matches:
       - "<the matched line excerpt, as the hook reported it>"
     justification: <agent's diagnosis + user's confirmation>
   ```

   Always record `matches` — it binds the override to the exact content the user reviewed. Without
   it the override covers the pattern for the whole file forever, which means a *real* secret later
   added to the same file would sail through on the strength of an old approval.

3. Retry the push. The hook re-runs and exits 0 only if every match is now covered. If new matches surface (e.g., the file body changed), repeat the diagnose-and-classify cycle.

**Override scope:** per-file, per-pattern, and — when `matches` is recorded — per-excerpt. An
excerpt-bound override covers a listed pattern only on lines containing a recorded excerpt, so
editing the matched line, or a new match of the same pattern elsewhere in the file, blocks again
and must be re-reviewed. A legacy override without `matches` keeps the old file-wide scope; treat
that as a migration state, not a choice. `classification.*` findings can never be overridden.

## Subagent / non-interactive contexts

When this Apiary skill is invoked from a subagent (no `AskUserQuestion` access):

- **Case A still works** — redact-and-retry is autonomous; the agent doesn't need the user.
- **Case B is unavailable** — the subagent cannot record an override without user confirmation. Treat any suspected false positive as Case C: do not push, return the finding to the caller. The main context can re-run the diagnose-and-confirm flow and record an override if appropriate.

The hook itself is content-only and never prompts — it just reports findings and exits non-zero. All interactive and editorial decisions belong to the agent.
