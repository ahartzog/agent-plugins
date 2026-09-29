# Wrap anatomy

A wrap has up to seven phases. The order carries the design: each phase consumes what the
one before it produced. Keep each phase that sessions in this repo can give work to; fold
it into another phase when its actions live there.

## Scope rule

The wrap acts on **this session's** checkouts, branches, change requests, tracker items,
memories and processes. It recognises its own work by evidence the session produced: paths
it created, branches it cut, items it claimed, PIDs it launched. In a checkout other sessions
also edit, the evidence is file-level: the working-tree state when the session started (Claude
Code records a git status snapshot at session start, and the transcript keeps it) and the
files the session's own edit and write calls touched. Each dirty path is then own,
pre-existing, or mixed; the wrap commits only its own and names the rest in the handoff. Anything else belongs to
another session, another person, or another repo. The wrap reports on that and leaves it
untouched. When the repo has a sweeper, repo-wide cleanup is the sweeper's job.

## Phases

| # | Phase | Purpose | Done when |
| --- | --- | --- | --- |
| 1 | Inventory | List what this session touched, from live state: working-tree status, unpushed or unmerged commits, change requests, claimed items, processes it launched | Every checkout, item and process the session touched is listed with its state |
| 2 | Route and retro | Send each learning to its home from the routing table, and run the retro questions | Every candidate learning is routed or dropped with a reason, and each retro finding is an edit or a tracker item |
| 3 | Land or park | Run the gates, then land per the owner's authority; park unfinished work with its next step | Every authored change is landed, parked, or named in the handoff as left uncommitted |
| 4 | Tracker | Set status on touched items, close items a merge finished, sync | Every touched item's status matches reality, and the sync has succeeded or its failure is reported |
| 5 | Release | Stop processes the session launched, release its locks, restore device or environment settings it changed | Every resource the session held is released, or named in the handoff |
| 6 | Workspace | Retire the session's merged worktrees and branches | Only unmerged or dirty session checkouts remain, each named in the handoff |
| 7 | Handoff | Tell the owner what changed, what was validated, what is left, and what they must do | The message's first line and closing block stand on their own |

## Ordering constraints

- **Route and retro before land.** Doc edits and retro edits ride in the same change as the
  session's work. After the merge, an edit needs a second change or gets stranded.
- **Tracker timing follows where the tracker stores items.** A tracker with its own store
  (Beads, GitHub Issues, Linear, Jira) closes items after the merge, citing the merge commit.
  A tracker inside the repo (a markdown list, a queue section) is a file edit, so the change
  rides in phase 3 and phase 4 folds into it.
- **Release before workspace cleanup.** A running dev server or editor holds files in the
  worktree.
- **Workspace cleanup after landing.** Removing a worktree with unlanded commits destroys work.

## Landing and parking by integration style

| Survey finding | Land | Park unfinished work |
| --- | --- | --- |
| Remote with change requests | Push the branch, open or update the change request, merge per authority | Push the branch and leave a draft change request with what's done, what isn't, and the next step |
| Remote, direct commits to the default branch | Commit and push per authority | Push a `wip/<topic>` branch; add a status line where the next session reads it |
| No remote | Commit to the default branch per authority | Commit on a local `wip/<topic>` branch; add a status line on the default branch where the next session reads it |
| A push or merge deploys | Land only with the deploy authority step 2 granted | Park on a branch that doesn't deploy |

A park note on an unmerged branch is invisible to a session that starts on the default
branch. The status line on the default branch, or the tracker item, is what the next session
finds. The handoff reaches the owner, not the next agent.

## Hazards

Each hazard applies only when its survey fact holds. Step 3 of the design marks each one as
triggered or not, and the wrap uses a workaround only for a triggered hazard.

| Hazard | Triggered when | Workaround |
| --- | --- | --- |
| Plain `git worktree remove` refuses a worktree whose only dirty files are editor or tracker churn | A fresh checkout shows churn files (generated metadata, tracker exports) | Classify churn the way the repo's cleanup tool does; use `--force` only when nothing authored is dirty |
| `git branch -d` refuses after the host deletes the merged remote branch | The host deletes branches on merge | Check `git merge-base --is-ancestor <branch> origin/<main>`, then `git branch -D` |
| The cleanup tool skips the checkout it runs from | The repo's cleanup tool has that rule | Run it from the primary checkout |
| Zero-grace, repo-wide cleanup removes other sessions' live worktrees | Several sessions share the repo | Keep the tool's grace period for repo-wide runs |
| Reopening an item that an open draft carries invites duplicate work | The tracker has claims and drafts | Keep it claimed and link the draft |
| Restoring a shared device or lock interrupts the session holding it | The repo has a shared lock or device | Probe the lock first |
| Killing by port stops a server someone else is using | Sessions run servers on fixed ports | Stop only PIDs the session launched |
| The session starts on a dirty tree it didn't write, and a broad `git add` commits someone else's work | Sessions edit the primary checkout rather than their own worktree | Stage this session's paths by name; never `git add -A`, `git add .` or `git commit -a` |
| A session-close line inside a tool-managed block is regenerated away | The instructions file has a generated block | Put the pointer line outside the block |
| Worktrees cut before the wrap landed don't see it | Sessions work in long-lived worktrees | Name them in the landing handoff; merging the default branch in brings the wrap |
| A gate fails on the default branch too | Survey row Gates shows a failure there | The wrap reports it and lands only with the owner's acceptance of that failure |
| Recall-only harvest misses early-session learnings | Sessions run long or compact | Scan the transcript (`learning-loop.md`, Harvest input) |

## Report-only mode

Every wrap supports a mode that prints each action and its command instead of taking it. In
Claude Code, invoking `/repo-wrap report-only` passes `report-only` to the skill as an
argument. When the skill body has no `$ARGUMENTS` placeholder, Claude Code appends
`ARGUMENTS: report-only` to it ([skills: pass arguments](https://code.claude.com/docs/en/skills)).
The design's verification uses this mode. So does an owner who hasn't granted write authority.
