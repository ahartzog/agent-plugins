---
name: design-repo-wrap
description: Designs, installs and verifies a repo-specific session-close skill (a wrap) for the current repository, so each session's loose ends close and its learnings land where the next session loads them. Use when setting up a wrap in a repo, or auditing or rebuilding an existing end-of-session routine.
---

# Design a repo wrap

A **wrap** is the routine an agent runs at the end of a working session in one repository.
It closes the session's loose ends and folds what the session learned into the places the
next session loads at startup. Every repo tracks work, keeps knowledge, integrates and
releases changes differently, so every repo needs its own wrap. This skill is the portable
part: it surveys the repo, designs that repo's wrap with the owner, installs it where the
repo's agents can call it, and proves it works.

Run it from the repository root. Paths below are relative to this skill's folder.

| Read | When |
| --- | --- |
| [references/discovery.md](references/discovery.md) | Step 1 |
| [references/learning-loop.md](references/learning-loop.md) | Step 3 |
| [references/wrap-anatomy.md](references/wrap-anatomy.md) | Steps 3 and 4 |
| [references/making-it-callable.md](references/making-it-callable.md) | Steps 4 to 6 |
| [templates/repo-wrap-SKILL.md](templates/repo-wrap-SKILL.md) | Step 4 |
| [examples/stickwars-repo-wrap.md](examples/stickwars-repo-wrap.md) | Step 4, as one finished wrap |

## Proposal mode

When the owner asks for a proposal only, run steps 1 to 4 against the repo read-only. Write
these to a folder outside the repo:

- `survey.md`: the filled survey table.
- `decisions.md`: step 2's questions, each with the owner's answer or the default taken,
  then "Owner items the survey found": uncommitted work, stale memories and other loose ends
  that need the owner, each marked as seeded into a home by the landing change or left to the
  owner. A proposal proceeds on the defaults and marks them.
- `routing.md`: the routing table, the phases kept, folded or dropped with reasons, and every
  edit the design needs outside the wrap (instructions-file lines, new doc sections, moved
  memory entries) as proposed patches.
- `SKILL.md`: the drafted wrap, with its links written for its install location.

In proposal mode a command counts as verified when `--help` answers, when the repo's script
manifest defines it (`package.json` scripts, `justfile`, `Makefile`), or when the file exists.
Gate status comes from a disposable copy outside the repo
(`git archive HEAD | tar -x -C <tmp>`, then install and run there); when that isn't possible,
record the gate as "not run" and its hazard as undecided. Proposal mode writes nothing inside
the repo.

## 1. Survey the repo

Fill the survey table in `references/discovery.md`. Every cell cites the file, command or
config that proves it, or says "none found" and lists the places checked. An existing
session-close routine is input: keep what works, and record what it misses.

Done when every row of the survey table has a cited answer.

## 2. Ask the owner what the repo can't answer

Ask these in one message, each with a recommended default drawn from the survey:

1. **Authority** at wrap time: report only, commit, push, open change requests, merge, or
   merge only on the owner's approval in that session. When a push or merge to the default
   branch deploys (survey row Release), say so in the question. The answer is standing
   authorisation: invoking the wrap grants it, whatever the agent's default caution.
2. **Homes** for any learning class the survey found no home for. Propose the smallest home
   the next session already reads, within the size rule in `references/learning-loop.md`.
3. **Agents and name**: which agents run working sessions in this repo, and the wrap's name.
   The default is `repo-wrap`. Check the owner's personal skill folders: a personal skill
   with the same name shadows the project one in Claude Code.
4. **Off-limits**: other people's branches, sibling repos, shared environments, production,
   paid resources.

Take the survey's answer for everything else. Done when each question has an answer or a
recorded default.

## 3. Design the loop

1. Build the routing table from `references/learning-loop.md`: each learning class gets one
   home, and each home gets the startup path that loads it.
2. Pick the phases from `references/wrap-anatomy.md`. Judge each by what sessions in this repo
   can create, beyond what exists today: a repo with no worktrees now still keeps the
   workspace phase when its agents' tools cut worktrees. Fold a phase into another when its
   actions live there, such as a markdown tracker whose edits ride in the session's commit.
3. Mark each hazard in `references/wrap-anatomy.md` as triggered or not, by its survey fact.
4. Run the retro questions in `references/learning-loop.md` against the existing
   session-close routine, if there is one, and carry each finding into the design.

Done when every routing row names its startup path with a file and line (or, for a home this
design creates, the line it will follow, and for a memory store, its index file), and every
kept phase names the repo's own command for each action.

## 4. Write the wrap

Fill `templates/repo-wrap-SKILL.md` at the skill location from
`references/making-it-callable.md`. Replace every `{{placeholder}}`.

- Point at the repo's own docs, scripts and commands. A rule the repo records nowhere, or
  one found only in a per-machine memory, goes into the repo's docs in the same change as
  the wrap; the wrap points at it.
- Use a hazard's workaround only where step 3 marked the hazard triggered. Otherwise use the
  template's safe default.
- Scope every destructive action to this session's own work, and say how the agent
  recognises its own: paths it created, branches it cut, items it claimed, PIDs it started.
- End every step on a completion criterion an agent can check.

Done when no `{{` remains, and every command in the wrap is verified (`--help`, a dry run,
the script manifest, or the file on disk).

## 5. Make it callable

Follow `references/making-it-callable.md` for each agent from step 2: one source folder,
links for the other agents, and the two instruction lines (route-as-you-go and the pointer)
that replace the older session-close text.

## 6. Verify

1. **Discovery.** A fresh headless session of each agent lists the wrap. Run the same probe
   where the link is absent and show the difference.
2. **Dry run.** Invoke the wrap with `report-only` against this design session: every step
   prints what it would do and which command it would use. Fix each step that can't be
   carried out as written, then run it again.
3. **Links.** Every relative link in the wrap resolves from the wrap's folder.

Done when all three pass. Keep their output for step 7.

## 7. Land it

Commit the wrap, the links, the instruction lines and the doc edits from step 4 as one change
through the repo's integration path. Put the survey, the routing table and the step 6 output
in the change description. Tell the owner the invocation, and name any existing worktree that
needs the default branch merged in before it sees the wrap (`references/making-it-callable.md`). The
first real session close is the wrap's field test; its retro records what that session finds.
