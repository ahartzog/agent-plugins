# Discovery: survey the repo

The wrap acts on the repo's own machinery, so the design starts from what the repo actually
runs. Read the files and run the read-only commands. History and config show what the repo
does, and prose can be stale: when a doc and the config disagree, record both.

## Survey table

Copy this table into the design notes and fill one row per dimension. Cite a path, a command
or a config key in every cell.

| Dimension | Question | Answer | Evidence |
| --- | --- | --- | --- |
| Instructions | What does an agent load at session start here, from the repo and from the user's own config? | | |
| Agents | Which agents run working sessions in this repo? | | |
| Work tracking | Where do tasks, bugs and follow-ups live; how is an item claimed and closed; is it kept current? | | |
| Knowledge homes | Where do how-tos, decisions, pitfalls and environment facts live, and what do the memory stores hold? | | |
| Other owners | Which learnings belong to another repo or system (a sibling repo, a notes vault, a wiki)? | | |
| Integration | How does a change reach the default branch, is there a remote, and who may merge? | | |
| Release | Does a push or merge deploy anything, and where? | | |
| Gates | Which checks must pass before a change lands, how is each run locally, and which fail on the default branch today? | | |
| Workspace | Which worktrees, branches, stashes or scratch folders can sessions create? | | |
| Shared resources | What processes, locks, devices, containers or ports do sessions hold, and how does a session tell which are its own? | | |
| Human queue | Where do judgments only a person can make wait for that person? | | |
| Sweeper | What runs on a schedule, or in CI, to clean up across all sessions? | | |
| Existing close | What does the repo already say or do at session end? | | |

## Where to look

### Instructions and agents

Repo files: `AGENTS.md`, `CLAUDE.md` (often a symlink to `AGENTS.md`), `GEMINI.md`,
`.github/copilot-instructions.md`, `.cursor/rules/`, and nested copies in subfolders. Hooks:
`.claude/settings.json` (`SessionStart`, `UserPromptSubmit`) and `.codex/hooks.json`; a
hook's output is startup context too. Existing skills: `.claude/skills/`, `.agents/skills/`,
`.codex/skills/`.

User files load in every repo, so read them as context, and leave them unedited:
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, personal skill folders. They show rules the wrap
must respect and end-of-session skills it must coexist with.

Agents that run sessions: commit trailers (`git log --format=%b | grep -c Co-Authored-By`),
branch prefixes (`claude/`, `codex/`), agent config folders. An agent the owner has installed
but only calls as a delegate from another agent doesn't count.

### Work tracking

| Signal | Tracker | Typical commands |
| --- | --- | --- |
| `.beads/` | Beads | `bd ready`, `bd update <id> --claim`, `bd close <id>`, `bd dolt push` |
| Issue links and `Closes #n` in PR bodies, `.github/ISSUE_TEMPLATE/` | GitHub Issues | `gh issue list`, `gh issue close` |
| `LIN-123`-style keys in commits or branch names | Linear | Linear MCP or CLI |
| `ABC-123` keys and a Jira link in the docs | Jira | Jira MCP or CLI |
| `TODO.md`, a queue section in the instructions file, checkbox plans | Markdown in the repo | edit the file |
| None of the above | None | propose one in step 2 |

Check that a candidate tracker is live before routing work to it: compare its closed or
ticked items against `git log`. A plan whose boxes all sit unticked while its tasks are
committed is a design doc, not a tracker. Record the close convention: closed on merge,
closed by the author, or never closed.

### Knowledge homes and other owners

`docs/` (ADRs, `decisions.md`, runbooks, setup guides), `CONTRIBUTING.md`, READMEs, wikis
linked from them. For each home, record whether anything loads it at session start.

Read every memory entry and classify it: an environment fact, a repo rule misrouted into
memory, or a duplicate of a doc. Claude Code keeps per-machine memory in
`~/.claude/projects/<slug>/memory/`. The slug is the path of the folder the session started
in, with `/` and `.` replaced by `-`, so a worktree or a session started in a sibling repo
uses a different folder. Find every one that mentions this repo:
`grep -rl <repo-name> ~/.claude/projects/*/memory/`. Tracker memories (`bd memories`) are
shared.

Other owners: the instructions file often says which facts belong elsewhere (a notes vault,
a sibling repo that deploys this one). The wrap routes those learnings to that owner's
process and leaves that owner's files untouched.

### Integration, release and gates

Find the real host first. When `origin` is a local path, read that checkout's
`git remote -v`. When there is no remote at all, the repo is local-only: record where
commits land and how work is parked without a push.

Integration evidence, strongest first: branch protection
(`gh api repos/{owner}/{repo}/branches/main/protection`, often 403 on a free private repo),
the PR template, merged PRs (`gh pr list --state merged --limit 10`), then
`git log --merges --oneline -20` and merge-commit trailers when the host shows little.
Record who merges: the author, any agent, or only a human.

Release: deploy adapters and configs (`adapter-netlify`, `adapter-vercel`, `netlify.toml`,
`vercel.json`, `fly.toml`), deploy workflows in `.github/workflows/`, and deployment docs.
When a push to the default branch deploys, step 2's authority question must say so.

Gates: CI workflows and the task runner (`justfile`, `Makefile`, `package.json` scripts,
`pyproject.toml`, `Taskfile.yml`). Record the local command for each gate, and whether it
passes on the default branch today. The wrap needs a rule for a gate that already fails
there.

### Workspace

`git worktree list`, `git branch --list`, `git stash list`, the folders where sessions create
checkouts (`.claude/worktrees/`, `.worktrees/`, scratch folders), and the owner's tools that
cut worktrees. Read a cleanup tool's safety rules (dirty files, grace periods, the checkout it
runs from) before the wrap calls it. Record whether the host deletes merged branches
(`gh repo view --json deleteBranchOnMerge`) and which files show as churn in a fresh checkout.

### Shared resources

Dev servers and watchers (`dev` scripts, `docker compose`), lock files and lease helpers,
connected devices (`adb devices`, simulators), local databases, ports. For each one, record
how a session attributes it: the PID it launched, a lock it holds, a container it named.
A port alone doesn't show ownership: a person may be using the same server.

### Human queue

Review checklists, "needs human" labels, QA or playtest queues, design review folders.
When the survey finds a judgment owed with nowhere to wait, propose seeding a queue with it.

### Sweeper

Scheduled workflows (`on: schedule`), cron or launchd jobs named in the docs, janitor
scripts. A sweeper covers repo-wide cleanup, so the wrap stays scoped to its own session.

### Existing close

The instructions file, `CONTRIBUTING.md`, the final task of plan documents, overnight-run
instructions, and skills already in the repo. When the existing close covers only some
sessions, such as plan runs, record what happens in the others.
