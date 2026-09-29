---
name: repo-wrap
description: {{Repo name}} session close. {{One sentence naming only the phases this wrap kept, e.g. "Lands or parks this session's work, routes what it learned into <homes>, syncs <tracker>, retires worktrees and hands off."}} Use at the end of a {{repo name}} working session, in the session that did the work; `/repo-wrap report-only` prints the plan without acting.
---

<!--
Template for design-repo-wrap step 4. Replace every {{placeholder}}; <angle> slots inside
commands are runtime arguments and stay. Delete each section the design dropped, delete its
clause in the description, and renumber. Keep a hazard workaround only when design step 3
marked the hazard triggered. Every command must be the repo's own. Delete these comments.
-->

# Repo wrap

Run this in the session that did the work: what it changed and learned is not recoverable
from another session. From this skill folder the repository root is `{{../../..}}`. The rules
live in {{instructions file, integration doc, tracker doc}}; this skill orders them and points
at them.

**Scope.** This session's {{checkouts, branches, change requests, tracker items, memories,
processes}}. The session recognises its own by {{paths under its scratch folder, branches it
cut, items it claimed, PIDs it launched}}. {{Sweeper name and schedule}} handles the rest.

**Never, in any mode:** {{off-limits list from design step 2: other people's branches,
sibling repos, production, paid resources}}.

**Authority:** invoking this skill authorises {{the level from design step 2}}. When the
arguments include `report-only`, print each action and its command instead of taking it.

## 1. Inventory

1. {{Repo's status or briefing command, if any.}}
2. For each checkout this session created or worked in: branch, `git status --short`,
   {{commits not on its upstream | commits not on the default branch | commits since this
   session started}}, and
   {{its change request (command) | the park branch, if any}}.
3. The {{tracker}} items this session claimed, created or changed ({{command}}).
4. The processes this session launched, by PID, and the locks or devices it holds.

{{Churn files that show dirty in most checkouts, and how to leave them alone. Delete if none.}}

## 2. Route what the session learned, then retro

Harvest from {{the transcript: `find ~/.claude/projects -maxdepth 2 -name "${CLAUDE_SESSION_ID}.jsonl"` |
`git log` and `git diff` against the branch base | recall}}. List each learning a later agent
would otherwise rediscover, and send each to exactly one home:

| What it is | Where it goes |
| --- | --- |
| {{Owner direction that changes a rule}} | {{home}} |
| {{Work left, bug, follow-up}} | {{tracker item, with its parenting or labelling rule}} |
| {{How-to, pitfall, wrong doc}} | {{governing doc, committed with this session's work in step 3}} |
| {{Environment fact no doc records}} | {{memory store, dated}} |
| {{Human judgment owed}} | {{human queue}} |
| {{Owned by another repo or system}} | {{that owner's queue, or the handoff}} |

Delete any memory this session found restating a doc.

Then answer these about the session:

1. Did the session work around an instruction, doc or skill, this one included?
2. Did the owner correct the approach, beyond a fact?
3. Did the session rely on a heuristic the repo records nowhere?
4. Was a step skipped, or a rule followed that produced a worse result?

Each "yes" is an edit to that instruction, doc or wrap step, committed with this session's
work in step 3. An edit that needs an owner decision becomes a {{tracker}} item.

## 3. Land or park the work

Every authored change, step 2's edits included, ends {{committed and pushed | committed}}, or
the handoff names it as left uncommitted and why. {{Where commits happen: e.g. only in a
worktree this session created.}} Stage this session's paths by name
({{own-path evidence from step 1}}); a path another session left dirty stays unstaged and goes
in the handoff.

Before landing, run the gates for the paths changed: {{path glob → local command, one per
gate}}. {{Rule for a gate that also fails on the default branch.}}

- Ready work, meaning {{the repo's ready bar}}: {{landing action from the integration table in
  wrap-anatomy.md}}, then confirm {{the default branch}} contains it.
- Unfinished work: {{parking action from the same table}}, with what is done, what is not and
  the next step.
{{- A land that deploys: only with the deploy authority above.}}

## 4. {{Tracker}}

{{Delete this section when the tracker lives in the repo: its edits ride in step 3.}}

1. Update each item from step 1.3 with its status and a note saying what was done and what is
   next. An item whose work sits in this session's open draft stays claimed, with a link to
   the draft. {{Rule for other stopped work.}}
2. Close each item a merge from this session finished: {{close command citing the merge}}.
3. {{Sync command, and what to do when the sync is rejected.}}

## 5. Release {{resources}}

- Stop the processes from step 1.4 by PID. A server this session didn't launch stays up,
  even on the same port.
- {{For each shared lock or device: how to check it is free, then how to release or restore it.}}

## 6. Retire worktrees and branches

Run from the primary checkout.

1. Each of this session's worktrees whose branch has landed: confirm
   `git merge-base --is-ancestor <branch> {{origin/main | main}}` succeeds and
   `git -C <path> status --short` is empty. Then `git worktree remove <path>` and
   `git branch -d <branch>`. When either refuses, stop and name the worktree in the handoff.
   {{Triggered-hazard variants only: churn → --force after the churn check; host deletes
   merged branches → -D after the ancestry check.}}
2. {{Repo cleanup tool: dry run, then apply, with its default grace period. Delete if none.}}
3. A session worktree that stays goes in the handoff with its path and reason.

## 7. Handoff

End with a message the owner can act on from its first line and its closing block:

- What changed: {{change request numbers and merge commits | commit SHAs}}, items closed or filed.
- Validation actually run, with results; failures quoted.
- What is left: parked work, kept worktrees, blocked steps with the exact blocker, anything
  left uncommitted.
- Retro edits made, proposed edits to this wrap, and items filed for the owner.
- Human judgments owed, with their queue entry.
- When a human test is pending, the message ends with a numbered checklist: what to run, the
  steps in order, what to look at, what to report back, and whether the agent is blocked.
