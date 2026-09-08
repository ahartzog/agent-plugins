---
name: {HIVE_SLUG}
description: "{DESCRIPTION}"
allowed-tools: "Glob,Grep,Read,Edit,Write,Bash(*),Agent,Skill,AskUserQuestion,TodoWrite"
---

This is a thin skill. It delegates all operations to the Apiary (Hive Parent Protocol).

**Requires the Apiary plugin.** If `/apiary` is not available, fail with:
> ERROR: Apiary plugin required. Run: `claude plugin install apiary@ahartzog`

## Identity

- **Hive slug:** {HIVE_SLUG}
- **Git remote:** {GIT_REMOTE}

## On Invocation

Invoke `/apiary` in operate mode. The Apiary reads `hive.yml` from the Hive clone at `$HOME/.claude-hive/{HIVE_SLUG}/`, loads the persona from `PROTOCOL/agent-definition.md`, loads upstream protocol, and executes the requested workflow.

All git flow (clone, pull, sync, rebase-before-push) is handled by Apiary operate mode.

## Critical Rule

**NEVER write directly to `knowledge/`.** All contributions go through `_inbox/` and are processed by Parliament.
