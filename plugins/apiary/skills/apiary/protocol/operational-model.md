---
layer: PROTOCOL
type: operational-model
description: "End-to-end operating concept: how sessions, inbox accumulation, and Parliament fit together invisibly"
last_updated: 2026-04-16
codeowners: (read from hive.yml)
---

# Operational Model

This document describes how the Hive Mind works from the contributor's perspective. The goal: **users just talk to the skill. Everything else happens behind the scenes.**

---

## The Three-Phase Loop

```
  Session                    Accumulation               Incorporation
  ───────                    ────────────               ─────────────
  User invokes               Inbox files pile up        Parliament reads inbox,
  the Hive's skill  ──►      via direct push — on  ──►  produces PRs against
  Skill answers,             master, or on the          knowledge/. Fast-path
  writes _inbox/,            dedicated queue branch     auto-merges. Deliberation
  pushes.                    (inbox_transport).         goes through critics.
                             No coordination between    Under the queue transport,
                             sessions. No PRs needed.   Parliament then drains the
                                                        processed queue entries.
                             Sources deposited          Parliament cites sources
                             directly to sources/       during deliberation for
                             via Deposit workflow.      corroboration.
                             No Parliament needed.
```

### Phase 1: Session (invisible contribution)

1. User invokes the child Hive's skill (or /apiary) and asks a question, gets oriented, checks status, etc.
2. The skill reads `PROTOCOL/` and `knowledge/` to answer.
3. If the skill learns anything new during the conversation — a link, a person, a status update, a correction — it writes an inbox file to `_inbox/YYYY-MM-DD-<author>-<topic>.md`.
4. The skill commits and pushes the inbox file directly to master.
5. **Contributions are autonomous and require no user confirmation.** The agent writes to the inbox whenever it learns something new — it does not ask the user "should I contribute this?" Inbox writes are low-risk (append-only, reviewed by Parliament) and the friction of asking kills the flywheel. The Contribute workflow exists only for deliberate user-initiated submissions.

6. If the user provides primary source material and requests deposit, the skill follows the Deposit workflow in `PROTOCOL/workflows.md`: **verbatim text/markdown** is written natively to `sources/{doc-type}/`, while **binary documents** (PDF/PPTX/DOCX/XLSX) are routed to `/extract:ingest` (the Apiary does not parse binaries). Source deposits are independent of inbox contributions — a single session may produce both a source deposit (the raw transcript/document) and inbox contributions (learnings extracted from it). Full model: `PROTOCOL/sources-policy.md`.

### Phase 2: Accumulation (zero coordination)

Inbox files accumulate from all sessions on the Hive's **inbox transport** — a dedicated,
never-PR-gated queue branch (`inbox_transport: branch` — the recommended transport, scaffolded
into new Hives by default; see `references/inbox-transport-design.md`), or the default branch
itself (`inbox_transport: default-branch` — the legacy path, and what an absent field means, so
pre-2.23.0 Hives are unchanged). Either way, accumulation works without conflicts because:

- **Unique naming:** Each file is `YYYY-MM-DD-<author>-<topic>.md` — no two sessions produce the same filename.
- **Append-only:** Sessions create new files. They never modify existing inbox files or knowledge files.
- **Push retry:** If a push fails because the target ref moved (another session pushed first), the skill fetches, rebases, and retries. Since files never collide, the rebase always succeeds.

No PR is ever required for inbox files — direct push is the expected path on both transports. The
queue transport exists so a Hive can also give its default branch full vanilla protection
(required PR + codeowner review on everything): capture stays one direct push to the queue,
unreviewed content never enters default-branch history, and Parliament is the only bridge between
the two.

### Phase 3: Incorporation (Parliament)

Parliament processes the accumulated inbox into knowledge:

1. Collects all `status: ready` inbox files.
2. Routes contributions: `[link]`, `[person]`, `[tracker]` take the fast path (auto-merge). Everything else goes through the deliberation tribunal (Skeptic, Archivist, Cartographer critics -> Reviser -> Chancellor verdict).
3. Produces PRs against `knowledge/` — one auto-merge batch PR for fast-path and clean-MERGE deliberation outcomes; separate needs-review / rejection / escalation PRs otherwise (canonical rule: `custodian-workflow.md` §4.3).
4. Moves processed inbox files to `_inbox/_completed/`. Under the queue transport it then deletes the processed entries from the queue branch — after their `_completed/` records (content + original queue commit + author) are safely pushed, so attribution survives the deletion.

Full Parliament mechanics: upstream `protocol/custodian-workflow.md`

---

## Current Automation State

> Deployment state varies per install and drifts — treat this table as design intent, and verify scheduled/threshold triggers against your Hive's `_custodian/config.yml` and CI rather than trusting the Status column.

| Component | Status | How it works today |
|---|---|---|
| Session contribution | **Working** | Skill writes `_inbox/` and pushes on every invocation |
| Inbox accumulation | **Working** | Direct push to master, unique filenames prevent conflicts |
| Parliament (manual) | **Defined, not yet automated** | Run via `/{hive-slug} parliament` or `/apiary parliament` in a Claude session |
| Parliament (scheduled) | **Planned** | Hourly CI job — GitHub Action or CircleCI pipeline not yet stood up |
| Parliament (threshold) | **Planned** | Trigger when inbox reaches the `batch_threshold` configured in `_custodian/config.yml` |
| Audit | **Defined, not yet automated** | Run via `/apiary audit` in a Claude session |
| Brief | **Defined, not yet automated** | Run via the Hive's skill with "weekly summary" prompt |

### What needs to be built

1. **CI pipeline for Parliament.** A scheduled job (GitHub Actions cron or CircleCI scheduled workflow) that clones the repo, invokes the Parliament workflow via Claude CLI (`claude -p "run parliament"`), and posts results. Config target: hourly, per `_custodian/config.yml`.
2. **Branch protection for `_inbox/`** (default-branch transport only). GitHub branch protection rules must allow direct pushes to master for paths matching `_inbox/**`. This may require a bypass rule or a bot account, depending on your org's policy. Under `inbox_transport: branch` this problem does not exist — the queue branch is unprotected by design and master carries plain vanilla protection (`protocol/security-policy.md` § Repository Protection Model, transport=branch variant).
3. **CI pipeline for Audit.** Scheduled weekly, produces audit reports in `_custodian/reports/`.

---

## Permission Model

The skill needs to push to master without prompting the user for every git operation. This is configured in `.claude/settings.json` (checked into the repo):

```json
{
  "permissions": {
    "allow": [
      "Bash(git add _inbox/*)",
      "Bash(git add sources/*)",
      "Bash(git commit *)",
      "Bash(git push *)",
      "Bash(git pull *)"
    ]
  }
}
```

This grants auto-approval for git operations scoped to this repo only. Users working in this repo get frictionless inbox pushes. The permission does not propagate to other repositories. (The shipped template additionally allows the read and plumbing commands the queue-branch transport's push worktree and queue reads use — `git fetch`/`worktree`/`show`/`ls-tree`/`ls-remote`/`rev-parse`/`merge-base`/`rebase`/`sparse-checkout`/`hash-object`/`commit-tree`/`show-ref` — so a queue push needs no permission prompts; see `assets/child-settings-template.json` for the authoritative list.)

`git add` is scoped to `_inbox/*` and `sources/*` — the skill should never stage changes to `knowledge/` or `PROTOCOL/` files directly. Humans editing `knowledge/` by hand follow the direct-PR path (see `PROTOCOL/triage-policy.md` §"Human Direct-PR Path") — they branch, edit, push, and open a PR that CODEOWNERS review. Agents never open PRs against `knowledge/`.

---

## Sync and Push Discipline

All sync and push operations are **imperative** — executed by Apiary's operate mode at the right points in the workflow, not by hooks. This ensures they work regardless of where the user invoked the skill from.

### On session start: Sync to default branch

Operate mode Step 0's ff-sync phase fetches and fast-forward merges the remote default branch before any read or write operations. This ensures the agent reads current `knowledge/` and `_inbox/` state before answering or contributing.

- **Silent on success.** The user sees the clone/pull output only.
- **HALTS on divergence.** If the local clone has diverged, fast-forward fails and the session halts with an actionable reset instruction (`mode-operate.md` Step 0) — the agent never proceeds on stale data.

### Before every push: Rebase

Operate mode's Contribution Handling includes a mandatory pre-push rebase onto the push target's remote ref — the default branch, or the inbox queue branch under `inbox_transport: branch`. This prevents push rejections from concurrent sessions.

- **No merge commits.** Rebase keeps inbox history linear.
- **Safe because sessions write unique files.** Inbox files are `YYYY-MM-DD-<author>-<topic>.md` — no two sessions modify the same file, so rebase conflicts are structurally impossible for inbox writes.
- **Warns on failure.** If rebase fails (e.g., user modified a knowledge file locally), the push is not attempted. The agent should surface this to the user.

---

## What Contributors Experience

**Ideal case (everything working):**
> You invoke the Hive's skill, ask a question about the domain. The skill reads knowledge files, answers your question, notices you mentioned a new blocker, writes it to `_inbox/`, pushes. You never see the contribution happen. Later, Parliament incorporates it into the appropriate knowledge file via PR.

**If Parliament hasn't run yet:**
> Inbox files accumulate. The knowledge base doesn't update until Parliament processes them. Status queries may miss very recent contributions. The skill mitigates this by checking `_inbox/` for pending items during Status workflow (step 3 of Status in `PROTOCOL/workflows.md`).

**If push fails:**
> The skill retries with rebase. If it still fails (network issue, auth expired), the contribution is lost for that session. The skill should warn the user: "I couldn't push the inbox file. The contribution from this session was not recorded."

---

## Three-Layer Architecture

Every Hive Mind operates within a three-layer stack:

| Layer | What it is | Where it lives |
|---|---|---|
| **Apiary** | Shared protocol, agent roles, Parliament mechanics | Installed plugin: `~/.claude/plugins/cache/apiary/` |
| **hive.yml** | Per-Hive configuration: slug, remote, branch, codeowners, knowledge schema | `{hive-repo}/hive.yml` |
| **Content** | Knowledge files, inbox, sources, custodian reports | `{hive-repo}/knowledge/`, `_inbox/`, `sources/`, `_custodian/` |

The Apiary layer is read-only from any individual Hive's perspective. Changes to protocol files require a PR to the Apiary plugin repository. **The Apiary plugin is a hard dependency** — child Hive skills declare it in their `plugin.json` dependencies and will not function without it. Protocol files are read directly from the installed plugin at runtime; no vendoring or syncing is required.

The hive.yml layer is the parameterization surface — it is where a Hive customizes behavior without forking protocol. The content layer is Hive-specific and fully owned by the Hive's CODEOWNERS.

---

## Sentinel (Step 0)

Before any Parliament agent processes a contribution, Sentinel runs a mandatory security scan. Sentinel cannot be disabled or skipped.

Sentinel scans for: PII beyond professional attribution, and credentials/tokens/keys. Hard rejections go to `_inbox/_quarantine/` with a Sentinel report; `/apiary audit` surfaces unaddressed quarantine items to CODEOWNERS (Sentinel Retrospective). Other contributions in the batch continue. A Hive that needs a sensitivity-marking check beyond PII/credentials declares one as a gate extension (`references/authoring-gate-extensions.md`), enforced at push time.

After every Parliament run, Sentinel performs a tail-check: structural validation, quarantine retrospective, and version check. Findings are appended to the Parliament run report.

Full Sentinel definition: `PROTOCOL/custodian-workflow.md` Section 0.

---

## Design Principle: Invisible Until It Breaks

The contribution pipeline should be invisible to the user during normal operation. The only times a user should be aware of the pipeline are:

1. **Push failure** — skill warns explicitly.
2. **Parliament PR review** — CODEOWNERS see deliberation PRs and can review.
3. **Audit findings** — periodic audit surfaces staleness, contradictions, or gaps.
4. **Explicit invocation** — user runs Parliament, Audit, or Brief workflows on purpose.

Everything else is background machinery.
