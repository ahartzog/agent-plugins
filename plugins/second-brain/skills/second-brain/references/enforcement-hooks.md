# Enforcement Hooks — When Prompts Aren't Enough

**Hooks guarantee; prompts suggest.** Everything in the hub CLAUDE.md and agent files is advisory — a long session, a compacted context, or a distracted model can talk past it. Claude Code hooks execute deterministically. This reference tells you which loop disciplines deserve hook backing and how to wire them.

This is an **L4 feature**. Don't add hooks to a young hub — prompt-level discipline plus the custodian catches most drift, and hooks add maintenance surface. Add a hook when the audit shows the same discipline failing repeatedly despite prompt text (that's Loop E telling you the instruction layer isn't enough).

## Decision Matrix

| Discipline | Mechanism | Why |
|---|---|---|
| Custodian staleness nudge at session start | `SessionStart` hook | A nudge in CLAUDE.md depends on the model noticing; a hook injects it every session |
| Retrospection reminder at session end | `Stop` hook (advisory) | Sessions end unpredictably; the task-completion gate covers most cases, the hook catches the rest |
| Block writes to raw/source data dirs | `PreToolUse` hook (deny) | "Immutable raw layer" must be mechanical — agents should never rewrite source exports |
| Sensitive-data scan before git push | `PreToolUse` hook on `git push` | Credential/PII patterns are regex-checkable; prompt-level "be careful" is not enforcement |
| Static conventions, judgment frames | CLAUDE.md / agent file | Judgment can't be a hook; this is what the prompt layer is for |

## Hook Recipes

Add to the hub's `.claude/settings.json`. All recipes degrade gracefully (exit 0 on any error — a broken hook must never block work).

### 1. Custodian staleness nudge (SessionStart)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'r=$(ls -t \"$CLAUDE_PROJECT_DIR\"/_reports/custodian-*.md 2>/dev/null | head -1); if [ -z \"$r\" ]; then echo \"[custodian] No custodian run found — consider running the custodian workflow.\"; elif [ $(( ($(date +%s) - $(stat -f %m \"$r\")) / 86400 )) -gt 14 ]; then echo \"[custodian] Last custodian run: $(basename \"$r\") — more than 14 days ago. Consider running it.\"; fi; exit 0'"
          }
        ]
      }
    ]
  }
}
```

### 2. Retrospection reminder (Stop, advisory — with a conditional escalation variant)

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'cd \"$CLAUDE_PROJECT_DIR\" 2>/dev/null && if ! git diff --quiet 2>/dev/null; then echo \"[loops] Uncommitted vault changes — did the contribution reflex fire for everything learned this session?\"; fi; exit 0'"
          }
        ]
      }
    ]
  }
}
```

Keep `Stop` hooks advisory (informational output, exit 0). Blocking stop-hooks in a personal vault are friction that leads to the whole system being disabled — retention beats enforcement strength.

**Conditional self-clearing variant (wrap's forward contract).** If loop-health telemetry shows active sessions where `/wrap` never ran despite knowledge activity, escalate this recipe — but only conditionally: block **once per session**, and only when knowledge files were touched AND the hub's `.session-gate` marker is older than the session's changes; wrap's final stage (`references/mode-wrap.md` stage 5) touches the marker, which self-clears the block. The condition set is what keeps this survivable — an unconditional blocking Stop hook gets disabled within a week.

### 3. Protect the raw data layer (PreToolUse deny)

For hubs that keep immutable source exports (e.g., `Financial/data/`, `Medical/exports/`): use a `PreToolUse` hook matching `Write|Edit` and deny when the target path is inside a protected directory. See the Claude Code hooks reference for the JSON decision format (`hookSpecificOutput.permissionDecision: "deny"`). The protected-paths list lives in the hook script so the custodian can audit it.

**Why:** agent-rewritten source data is the "model collapse" failure mode — synthesis layers can be regenerated, raw layers can't.

### 4. Sentinel pre-push scan (git pre-push)

For any vault that auto-pushes to a remote on a timer (Obsidian Git plugin, launchd/cron backup) the push happens with no human in the loop — so the last gate against a leaked credential or SSN is a git `pre-push` hook, not prompt discipline. Ship `assets/sentinel-patterns.json` (credential + gross-PII regexes; *not* the vault's normal financial/medical content) and `assets/pre-push-sentinel.sh`, and install both into the vault:

```bash
mkdir -p "$VAULT/.claude/hooks"
cp assets/sentinel-patterns.json assets/pre-push-sentinel.sh "$VAULT/.claude/hooks/"
chmod +x "$VAULT/.claude/hooks/pre-push-sentinel.sh"
ln -sf ../../.claude/hooks/pre-push-sentinel.sh "$VAULT/.git/hooks/pre-push"
```

**Self-install, because git hooks aren't versioned.** A fresh `git clone` restores `.claude/hooks/` (tracked) but NOT `.git/hooks/pre-push` (not tracked) — so the protection silently vanishes on a new machine. Have a `SessionStart` hook re-create the symlink every session (idempotent `ln -sf`); then even the sentinel needs no manual step. Record the dependency in the per-machine setup registry.

**Design constraints (keep these):** fail-open (a broken hook exits 0 — it must never block real work), single source of truth (`sentinel-patterns.json` is read by the hook, never duplicated inline), and an explicit bypass for confirmed false positives (`SENTINEL_SKIP=1 git push`).

**Why:** the vault legitimately contains sensitive *content* (balances, conditions, policy numbers) — that's the point of the vault and must never be flagged. The sentinel targets a different class: secrets and identifiers that should never be committed anywhere (API keys, private keys, SSNs). apiary ships a Parliament-scoped sibling; this one is for single-operator vaults that aren't hives.

## Custodian Integration

The custodian's checklist should include: "Hooks present and executable? Hook scripts' protected-path lists match the hub's actual raw-data dirs?" Hooks are infrastructure; infrastructure gets audited like everything else (Loop C applies — when a hook misses something it should have caught, extend it).
