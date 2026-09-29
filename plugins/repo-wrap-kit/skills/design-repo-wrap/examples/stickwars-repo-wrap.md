# Example: the StickWars VR wrap

The wrap from the StickWars VR repository (`.agents/skills/repo-wrap/SKILL.md`), copied
verbatim at the end of this file as of commit `8aba83ea` (2026-09-27). Its relative links
point into the StickWars repo and don't resolve here. The repo is a Unity game two owners
build with Claude Code and Codex agents. It tracks work in Beads with a Dolt remote,
lets agents merge their own ready PRs, cuts a git worktree per feature, and shares one
headset and one Unity runtime lock across sessions. A weekly janitor job sweeps the repo.

## How it maps to the anatomy

Each choice below comes from a StickWars survey fact. A repo without that fact takes the
template's default instead.

| Anatomy phase | StickWars section | Choice | Survey fact behind it |
| --- | --- | --- | --- |
| Scope rule | Preamble | Own work = session scratchpad and `.claude/worktrees/` paths | Agents cut a worktree per feature; the weekly janitor sweeps the rest |
| 1 Inventory | 1. Inventory | `tools/mainline_sync.py --force` briefing; churn list | A session-start hook already gathers repo state; Unity `.meta` and `.beads/` churn shows in every checkout |
| 2 Route and retro | 2. Route what the session learned | Decision Beads, `decisions.md`, governing docs, dated `bd remember`, worn-headset queue | Owner decisions are tracker items; feel judgments need a person in the headset |
| 3 Land or park | 3. Land or park the work | Per-path gates; merge own ready PRs; draft PR to park | Hosted CI can't compile the Unity code, so gates run locally; the owners granted agents merge authority |
| 4 Tracker | 4. Beads | Close after merge citing the PR; id-collision check; Dolt sync | Beads has its own store and a Dolt remote shared by several clones |
| 5 Release | 5. Release the host and headset | Lease probe; proximity restore | One headset and one Unity runtime lock shared across sessions |
| 6 Workspace | 6. Retire worktrees | `--force` remove after a churn check; `branch -D` after an ancestry check; `worktree_gc.py` | Churn blocks plain remove; GitHub deletes merged branches; the cleanup tool skips its own checkout |
| 7 Handoff | 7. Handoff | Numbered test checklist | The owner tests builds in a headset |

This version has no retro questions. It predates the kit's retro rule, and its later fixes
arrived as separate commits after other sessions hit the gaps. A new wrap keeps the retro.

## How it was built and how it changed

1. **Plan review** before any file was written. It caught that the repo's worktree cleanup
   tool never touches the checkout it runs from. It also caught that a zero-grace cleanup
   run would remove other sessions' just-merged worktrees, and that the wrap's trigger
   phrases collided with the owner's personal notes-vault `/wrap`.
2. **Two adversarial review rounds** by independent reviewers, one refuter per finding.
   Round 1 confirmed 6 of 11 findings. Among them: route learnings before landing; plain
   `git worktree remove` fails on churn; a Bead in an open draft PR stays claimed.
   Round 2 confirmed 2 of 6 findings: a named lease probe, and churn defined by the
   cleanup tool's own pattern.
3. **Field changes** by later sessions (commits `7e131175`, `3e4759e1`, `8aba83ea`): a
   tracker id-collision check before every sync, and a stricter churn rule after the
   cleanup tool changed. A retro step makes these edits part of every wrap instead of
   leaving them to chance.


## The skill

````markdown
---
name: repo-wrap
description: StickWars repository session close (not the Second Brain vault /wrap). Lands or parks this session's work, routes what the session learned into Beads and docs, closes and syncs Beads, releases the host and headset, retires worktrees and writes the handoff. Invoke as /repo-wrap at the end of a stickwars-vr working session, in the session that did the work.
---

# Repo wrap

Run this in the session that did the work: what it changed and learned is not recoverable
from another session. From this skill directory the repository root is `../../..`. The
rules live in `AGENTS.md`, [single-mainline.md](../../../docs/single-mainline.md) and
[beads-taxonomy.md](../../../docs/beads-taxonomy.md); this skill orders them and does
not restate them. Run every `bd` command from the primary checkout (first line of
`git worktree list`): a linked worktree has no Dolt store.

Scope is **this session's** checkouts, branches, PRs, Beads, memories and processes.
Never commit, stash, reset, clean or remove another session's work, and never kill a
process you cannot attribute to this session. The weekly janitor
([reports](../../../docs/janitor/README.md)) sweeps the rest of the repository.

## 1. Inventory

1. `python3 tools/mainline_sync.py --force` and read the briefing.
2. For each checkout this session created or worked in (its worktrees live under this
   session's scratchpad or `.claude/worktrees/`): branch, `git status --short`, commits
   not on its upstream, and its PR (`gh pr view --json state,isDraft,url`).
3. List the Beads this session claimed, created or changed.

Editor and tracker churn (edits to tracked `.beads/`, Unity `.meta`, XR settings, TMP atlases: the
`NOISE` pattern in `tools/worktree_gc.py`) appears in most checkouts. An untracked or newly staged
file is never churn, whatever its path; `worktree_gc.py` counts it as authored. Leave it alone: no
`git checkout --`, no clean, and JSONL ships only in a `chore(beads):` commit.

## 2. Route what the session learned

List each thing this session learned that the next agent would otherwise rediscover: a
pitfall, a command that works, a wrong doc, a tuning result, an owner direction. Send
each to exactly one home:

| What it is | Where it goes |
| --- | --- |
| An owner direction that changes a rule | A decision Bead, then its line in `docs/game-design/decisions.md` and the doc it changes |
| Work left to do, a bug, a follow-up | A Bead, parented per the taxonomy table |
| How to run, build, test or debug something; a doc that was wrong | An edit to the doc that governs it, committed with this session's work in step 3 |
| An environment fact no committed doc records | A dated `bd remember` |
| A human judgment owed (feel, comfort, readability, MR compositing) | One checkbox line in the worn queue in `docs/functional-checks.md` |

Delete any memory this session found restating a doc or decision Bead, including one its
own doc edit now covers: a `bd remember` key, or for Claude a per-machine auto-memory
file. Memories holding an environment fact no doc records keep their 90-day
re-verification. Nothing other agents need stays only in a per-machine memory.

## 3. Land or park the work

Every authored change, step 2's edits included, ends committed and pushed, or the
handoff names it as left uncommitted and why. Commit only in a worktree this session
created; authored edits found in the primary checkout move to a new worktree
(`git worktree add <scratchpad>/wt -b <branch> origin/main`) before they are committed.

Before pushing, run the gates `AGENTS.md` "Build & test" names for the paths changed:
`dotnet test core --nologo` for `core/**`, `python3 tools/unity_compile_gate.py` and
`python3 tools/boundary_check.py` for `unity/**`, and the Python tool checks in
`docs/local-development.md` for `tools/**`.

- Ready work, meaning checks, evidence and the PR template are complete: mark it ready,
  merge under single-mainline and verify `origin/main` contains the tip. The wrap never
  pushes a draft to ready to finish on time.
- Unfinished work: push the branch and leave a draft PR whose body says what is done,
  what is not and the next step.

## 4. Beads

1. Update each Bead from step 1.3: status, plus a note saying what was done and what
   is next. A Bead whose work sits in this session's open draft PR stays `in_progress`
   with a note linking that PR. Any other claimed Bead whose work stopped goes back to
   `open` unless the note names who continues it.
2. For every merge this session made, and every merged PR the briefing flags with an
   open `Closes` Bead: `bd close <id> -r "PR #<n> merged (<sha>)"`.
3. `python3 tools/beads_id_collisions.py`; on exit 1 follow
   [child-id collisions](../../../docs/beads-taxonomy.md#child-id-collisions-across-clones)
   before pulling; exit 2 (could not compare) goes in the handoff and the sync proceeds.
   Then `bd dolt pull`, then `bd dolt push`. On a rejected push, pull and
   push again; report it if it still fails.

## 5. Release the host and headset

- Stop the Unity editors, captures, watchers and background shells this session
  started. The runtime lease is an OS lock released when its owner exits; after a
  driver crash, check for its orphaned Unity or scrcpy children
  ([validation runbook](../../../docs/validation/README.md)).
- A headset whose proximity override this session disabled gets it back so it sleeps,
  cools and charges, once no other session holds the runtime lease. This probe prints
  `free` or raises `BlockingIOError` while an owner holds it:
  `python3 -c "import fcntl,os;f=open(f'/tmp/stickwars-host-runtime-{os.getuid()}.lock','a+');fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);print('free')"`.
  When it is held, leave the setting and name it in the handoff. Restore with
  `metavr device proximity --enable` or the metavr MCP `proximity_set enable=true`
  ([why](../../../docs/validation/quest-one-time-setup.md)). Restore any boundary or
  sleep setting this session changed.
- `npx beads-ui stop` if this session started it.

## 6. Retire worktrees

Run these from the primary checkout; `worktree_gc.py` never touches the checkout it runs
from.

1. Each of this session's worktrees whose branch merged: `git fetch origin`, then
   `git merge-base --is-ancestor <branch> origin/main` must succeed and the
   `python3 tools/worktree_gc.py` dry run must show `dirty=0` for its path. Then
   `git worktree remove --force <path>` (the churn blocks a plain remove) and
   `git branch -D <branch>` (plain `-d` refuses once GitHub has deleted the upstream).
2. `python3 tools/worktree_gc.py`, read the plan, then
   `python3 tools/worktree_gc.py --apply` with the default grace period. Never pass
   `--grace-minutes 0` for the whole repository: it removes worktrees other sessions
   just merged and are still using.
3. A worktree of this session that stays (unmerged, or still dirty) goes in the handoff
   with its path and reason.

## 7. Handoff

End with a message the owner can act on from its first line and its last block:

- What changed: PR numbers and merge SHAs, Beads closed or filed.
- Validation actually run, with results; failures quoted, not summarized.
- What is left: drafts, kept worktrees, blocked steps with the exact blocker, anything
  left uncommitted.
- Human judgments owed, with their worn-queue line.
- When a human test is pending, the message ends with a numbered checklist: which
  build, the steps in order, what to look at, what to report back, and whether the
  agent is blocked waiting.
````
