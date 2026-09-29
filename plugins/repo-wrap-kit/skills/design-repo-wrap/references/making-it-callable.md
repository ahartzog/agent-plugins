# Making the wrap callable

The wrap is a skill: a folder holding a `SKILL.md` with `name` and `description` frontmatter
([Agent Skills specification](https://agentskills.io/specification)). The folder lives in the
repo, so everyone who clones the repo gets it, and it changes through the same review as code.
Each agent discovers skills in its own folders, so one source folder plus links serves every
agent.

## Where each agent looks

Checked 2026-09-29 against each vendor's docs.

| Agent | Repo skill folders | User skill folders | Invoke | Source |
| --- | --- | --- | --- | --- |
| Claude Code | `.claude/skills/` (plus nested `<subdir>/.claude/skills/`) | `~/.claude/skills/` | `/name` | [skills](https://code.claude.com/docs/en/skills) |
| Codex CLI | `.agents/skills/` in each folder from the working directory up to the repo root | `~/.agents/skills/` | `/skills`, or `$name` | [build skills](https://learn.chatgpt.com/docs/build-skills) |
| Gemini CLI | `.gemini/skills/`, `.agents/skills/` | `~/.gemini/skills/`, `~/.agents/skills/` | `/skills` | [skills](https://geminicli.com/docs/cli/skills/) |
| Cursor | `.agents/skills/`, `.cursor/skills/`, also `.claude/skills/` and `.codex/skills/` | `~/.agents/skills/`, `~/.cursor/skills/` | `/name` | [skills](https://cursor.com/docs/context/skills) |
| GitHub Copilot | `.github/skills/`, `.claude/skills/`, `.agents/skills/` | `~/.copilot/skills/`, `~/.agents/skills/` | by description | [agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) |

Claude Code doesn't read `.agents/skills/`. Codex's docs don't list `.claude/skills/`.
Claude Code and Codex both follow symlinked skill folders.

## Install

1. **Source folder.** Put the wrap at `.agents/skills/<name>/SKILL.md`. When Claude Code is
   the only agent, `.claude/skills/<name>/SKILL.md` works on its own.
2. **Link for Claude Code.** When the repo has no `.claude/skills/` yet, link the whole
   folder so every repo skill reaches Claude:

   ```bash
   ln -s ../.agents/skills .claude/skills
   git add .claude/skills
   ```

   When `.claude/skills/` already holds Claude-only skills, link the one skill instead:
   `ln -s ../../.agents/skills/<name> .claude/skills/<name>`. Git stores either link as a
   symlink (mode `120000`). A Windows clone needs `git config core.symlinks true`, the same
   requirement as a `CLAUDE.md` → `AGENTS.md` link.
3. **Instruction lines.** Add two lines to the instructions file, outside any block a tool
   regenerates, and remove the old session-close text so the procedure lives in one place.
   The first tells agents to route learnings as they happen; the second points at the wrap,
   which catches what they missed:

   ```markdown
   - **Route what you learn when you learn it**: {{homes, e.g. follow-ups to the tracker,
     pitfalls to the governing doc, owner rules to this file}}.
   - **Close every session with the [repo-wrap skill]({{skill folder}}/repo-wrap/SKILL.md)**
     (`/repo-wrap`): it {{one clause naming what it does in this repo}}.
   ```

   The pointer reaches every agent that reads the instructions file, including one that
   doesn't discover skill folders: that agent follows the link and reads the file. Codex
   and Cursor read `AGENTS.md`. Claude Code reads `CLAUDE.md`, and reads `AGENTS.md` only
   when there is no `CLAUDE.md`
   ([memory](https://code.claude.com/docs/en/memory)). A `CLAUDE.md` → `AGENTS.md` symlink
   gives both agents one file.

## Name and invocation

- **Name.** In Claude Code, a personal skill beats a project skill with the same name
  ([skills: resolve skills that share a name](https://code.claude.com/docs/en/skills)).
  A personal `/wrap` would hide a project `/wrap`, so pick a repo-qualified name, such as
  `repo-wrap`. Name rules: lowercase letters, digits and single hyphens, up to 64 characters,
  matching the folder name.
- **Model-invoked.** Keep a `description` and leave `disable-model-invocation` unset. The
  pointer line tells agents to run the wrap, and an agent can invoke only a skill whose
  description it can see. Put the repo's name in the description, so the wrap doesn't
  compete with the owner's other end-of-session skills, such as a notes-vault wrap.
- **Frontmatter.** Keep to `name` and `description`, the two fields every agent in the table
  reads. Claude-only fields such as `argument-hint` are optional extras.
- **Description length.** Up to 1,024 characters under the Agent Skills specification.
  Claude Code caps `description` plus `when_to_use` at 1,536 characters. One or two sentences
  is enough.

## Verify discovery

Run each probe from the repo root, in a fresh process:

```bash
claude -p "Look only at the skills listed in your context. Is a skill named repo-wrap listed? Answer listed or not listed."
codex exec -s read-only "Is a skill named repo-wrap available to you? Answer available or not available."
```

Then run the Claude probe in a checkout without the link and confirm it answers
`not listed`. That difference shows the link does the work.

**Worktrees.** In a linked git worktree, Claude Code (v2.1.277 or later) loads the main
checkout's project skills only when the worktree has no `.claude/skills` folder at its root
([skills](https://code.claude.com/docs/en/skills)). Once the link is committed, every new
worktree carries it. A worktree cut before the wrap landed, from a commit that already had a
`.claude/skills` folder, doesn't see the wrap until the default branch is merged into it. Its
instructions file also predates the pointer line. In an interactive
Claude Code session, `/skills` lists every skill with its source. A new top-level skills
folder created during a session needs `/reload-skills`; changes inside an existing one are
picked up live.

## Optional: reminder at session end

A Claude Code `Stop` hook can check for unwrapped work (a dirty tree, unpushed commits)
and remind the agent to run the wrap before stopping
([hooks](https://code.claude.com/docs/en/hooks)). UNVERIFIED: the exact blocking behaviour,
so read the hooks page before relying on it. Keep any such hook conditional, and never
block every stop: a hook that nags on every turn gets disabled.
