# The learning loop

A session's learning improves the next session only when it lands somewhere the next session
loads without being asked. The session's own context disappears when the session ends or
compacts. A per-machine memory reaches only that machine's next session, and only when it
starts in the same folder. A doc with no pointer to it is found by luck. The wrap routes each
learning to a home that has a **startup path**.

## Startup paths

| Startup path | What it loads | Reach |
| --- | --- | --- |
| Instructions file (`AGENTS.md`, `CLAUDE.md`, nested copies) | Its full text, every session | Every agent that reads it |
| Pointer line in the instructions file | The linked doc, when the pointer's wording matches the task | Same |
| Skill description | The skill body, when the task matches | Agents that discover the skill folder |
| Session-start hook output | Whatever the hook prints: tracker queue, policy, repo status | Agents with the hook installed |
| Tracker ready queue | Open items, when the instructions or a hook tell the agent to check it | Everyone on the tracker |
| Memory index (Claude Code `MEMORY.md`, `bd memories`) | Memory lines, every session | One machine and start folder (auto-memory), or everyone (tracker memories) |

Cite a startup path by the file and line that loads the home. For a home inside the
instructions file, cite the section's line; the file's full load is the startup path. For a
home the design creates, cite the line it will follow. For a memory store, cite its index
file. A home with no startup
path is write-only: add a pointer line, or route that class somewhere else.

## Routing table

Build one for the repo, one row per learning class. Each learning goes to exactly one home.

| Learning class | Example | Typical home | Startup path |
| --- | --- | --- | --- |
| Owner direction that changes a rule | "Main is the only integration branch" | Instructions file or decision record | Instructions file |
| Work left, bug, follow-up | "The export skips archived rows" | Tracker item | Ready queue |
| How-to or pitfall; a doc that was wrong | "The build needs `JAVA_HOME` exported" | The doc that governs that area | Pointer line |
| Environment fact no doc records | "The test device's serial" | Dated memory entry | Memory index |
| Human judgment owed | "Does the new menu read at arm's length?" | Human queue | Pointer line or tracker |
| An instruction that failed or was worked around (the retro) | "The lint step runs on files the formatter already fixed" | That instruction, edited | The instruction itself |
| Owned by another repo or system | "The portal repo needs the new build copied in" | That owner's queue or process, or the handoff | That owner's startup path |

The retro row makes the repo's instructions better, not only its knowledge. It runs in the
routing phase, so its edits land with the session's work.

### Size rule for the instructions file

Everything in the instructions file loads every session. Keep there what every session
needs: rules, commands, pointers. Move a section that only some tasks need, or that has grown
past about 20 lines, into a doc, and leave a one-line pointer whose wording names when to
read it.

## Retro questions

The wrap asks these about the session. Each "yes" is an edit to the named instruction, doc or
skill, the wrap included, landed with the session's work. When the edit needs an owner
decision, it becomes a tracker item instead.

1. Did the session work around an instruction, doc or skill?
2. Did the owner correct the approach, tone or framing, beyond a fact?
3. Did the session rely on a heuristic the repo records nowhere?
4. Was a prescribed step skipped, or a rule followed that produced a worse result?

A wrap step that fails after landing (steps that run after the merge) goes in the handoff as
a proposed edit to the wrap, and the next session applies it.

## Harvest input

The wrap has to know what the session learned. The sources, strongest first:

1. **The session transcript.** Claude Code writes every turn to
   `~/.claude/projects/<slug>/<session-id>.jsonl`, and the file survives compaction. A
   Claude Code skill finds its own with
   `find ~/.claude/projects -maxdepth 2 -name "${CLAUDE_SESSION_ID}.jsonl"`, because Claude
   Code substitutes `${CLAUDE_SESSION_ID}` in skill content
   ([skills: string substitutions](https://code.claude.com/docs/en/skills)).
2. **The repo's own record.** `git log` and `git diff` against the branch base, the change
   description, and the tracker items the session touched.
3. **The agent's recall.** This works for a short session and degrades after compaction.

A repo with long sessions benefits from a transcript scan, delegated to a subagent that
returns candidates. Deciding what to keep stays with the session that did the work.

## Contribute continuously; the wrap verifies

Sessions end unpredictably. The repo's instructions should tell agents to route a learning
when it happens. The wrap catches the misses and re-checks the routing. A wrap that is the
only path for learnings loses everything from sessions that end without one.

## Prune on the way out

The loop also removes knowledge that has gone stale. The wrap deletes a memory entry that now
duplicates a doc, and a retro edit deletes the instruction it replaced. The design does the
same once: a repo rule found only in a memory moves into the repo's docs when the wrap lands.
A memory stored under another start folder (a sibling repo's slug) is that folder's startup
context too: propose its pruning to the owner, and leave it in place.
