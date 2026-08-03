---
layer: PROTOCOL
type: workflows
description: "Seven interaction workflows: triggers, behavior, and routing"
last_updated: 2026-07-30
codeowners: (read from hive.yml)
---

# Workflows

Seven interaction modes for the Hive's persona (defined in `PROTOCOL/agent-definition.md`). The session agent detects which workflow to use from user input.

---

## Cross-Cutting Discipline

These rules apply to **every** workflow that can produce inbox contributions (Ask, Status, Contribute, Audit, Brief). Individual workflows below reference this section rather than restating the rule.

**Progressive writes — autonomous, no confirmation required:** Record discoveries to the session inbox as they occur during the workflow, not batched at the end.
(Exception: source deposits via the Deposit workflow require explicit user intent — see §Deposit below. Deposits are large, intentional artifacts, not incidental discoveries.)
**Do not ask the user for permission to contribute.** Inbox writes are low-risk (append-only, Parliament reviews before merging to knowledge/) and high-value (unrecorded discoveries are lost). Write first, push immediately. Each inbox write is followed by `git commit` + `git push` before the session continues — local-only writes are invisible to Parliament. If push fails, retry once then queue locally and warn the user.

**Tag routing for discoveries:** When writing to the inbox, match the observation to a tag:
- Wrong fact with source → `[correction]`
- Wrong fact without source → `[contradiction]` (deliberation path; corrections require a source)
- New link / person / tracker → `[link]` / `[person]` / `[tracker]`
- Status change on work item → `[status]`
- Gap in workflows, coverage, or process → `[process]`
- Observation about the skill/PROTOCOL itself → `[meta]`
- Contradicts existing knowledge → `[contradiction]`

Full category taxonomy: `PROTOCOL/triage-policy.md`.

**Missing skill transparency:** If a workflow needs a skill or MCP the user hasn't installed, surface the gap explicitly — do not silently fall back. State: (1) which skill was needed, (2) the install command, (3) the fallback you're using and its caveats, (4) offer to walk through install. Full tool set and per-tool fallbacks: `PROTOCOL/tool-tiers.md`.

---

## Ask (Default)

**Triggers:** Any question, no explicit workflow specified, onboarding requests ("I'm new," "onboard me," "where do I start"), or ambiguous input.

**Behavior:**

1. **Clarify intent (when needed).** If the question is ambiguous about what the user is trying to accomplish, or they're clearly new, ask before routing: what are you trying to accomplish? What's your role/context? Don't ask both if one is obvious. Don't ask either if the question routes cleanly already.
2. **Route and load.** Identify relevant knowledge files per the routing rules in `PROTOCOL/agent-definition.md`, then **always run the Reference Library Discovery Protocol** — `protocol/routing-protocol.md` is canonical and governs everything downstream: retrieval, live search, and gap capture (a routing-table hit does not establish sufficiency). One file, one owner; this step deliberately does not restate it. Older personas may carry a frozen inline copy — the upstream file wins.
3. **Answer.** Grounded in the knowledge base, citing sources and `[learned:]` dates. Use linked trackers or skills to pull live data when relevant. Flag `confidence: low` or stale facts with a caveat. Be explicit when guessing.
4. **Learn.** Apply cross-cutting discipline (§above). Onboarding sessions and first-time questions are high-discovery windows — lean aggressive on contributions.
5. Log session to `_metrics/`.

---

## Status

**Triggers:** "What's happening with X?" "current state," "what are the blockers," "what's the status."

**Behavior:**
1. Read the Hive's primary status knowledge file (consult `PROTOCOL/agent-definition.md` for the correct file mapping).
2. Read the Hive's projects/work-items knowledge file.
3. Check recent inbox items in `_inbox/` for pending contributions that haven't been merged yet (these may contain fresher status than the knowledge base). Under `hive.yml.inbox_transport: branch`, pending entries live on the queue ref, not the local `_inbox/` — list them with `git ls-tree -r --name-only origin/{INBOX_BRANCH} -- _inbox/` and read one with `git show origin/{INBOX_BRANCH}:_inbox/<file>` (Step 0 already fetched the ref); also check the local `.inbox-worktree/_inbox/` if present (this machine's not-yet-pushed work) and any legacy pending files still in the clone's `_inbox/`. If Step 0 reported `INBOX_QUEUE_STALE` (offline), or a `git show` fails on a lazy blob fetch, answer from what is locally available and say so — "pending-contribution state as of the last successful sync" — rather than reporting the queue as empty.
4. Read linked trackers from the relevant knowledge file if the question is tracker-specific.
5. Synthesize a current-state briefing: what's on track, what's blocked, what's been decided recently, what needs attention.
6. Flag any information with stale `[learned:]` dates and recommend re-verification.
7. Apply cross-cutting discipline (§above).

---

## Contribute

**Triggers:** "I learned X," "here's a link," "this fact is wrong," "I want to add something," explicit contribution intent.

This workflow handles **explicit user-initiated contributions.** Most contributions happen autonomously via the cross-cutting progressive-writes discipline (§above) — the agent writes to the inbox without asking. The Contribute workflow is for when the user deliberately wants to submit something and wants to confirm the categorization.

**Behavior:**
1. Ask the user to describe what they want to contribute if not already clear.
2. Categorize the contribution using the taxonomy in `PROTOCOL/triage-policy.md`.
3. Confirm the category with the user: "This looks like a [correction]. Is that right?"
4. Confirm the target knowledge file.
5. Write the formatted contribution to the session inbox file:
   ```
   - [HH:MM] [tag] Description. Source if applicable.
   ```
6. Show the user exactly what was recorded.
7. Push the inbox file to remote.
8. Explain what happens next: "This will be processed by Parliament. [link] contributions auto-merge; [correction] contributions go through deliberation."

**For corrections:** Prompt for source. A correction without a source is recorded as `[contradiction]` (deliberation path) rather than `[correction]`.

**Cross-hive awareness (non-blocking):** Hives are federated — each knows its siblings via `hive.yml.siblings` (seeded from the [Hive Mind Registry](https://confluence.meridian.example/pages/viewpage.action?pageId=100000001) at create time, and reconciled by Parliament's Apiculturist on every run — `protocol/apiculturist-workflow.md`). Skip this entirely when `hive.yml.federation.cross_hive_routing` is `false` (default `true`) — the Hive has opted out of routing outward. Otherwise, if a contribution clearly falls outside this Hive's `purpose` and fits a sibling better, still record it here, then point the user to the better-matching `/sibling-slug`. Parliament does the authoritative routing under the classification direction guard — `custodian-workflow.md` §2.1 step 5 (authoritative).

---

## Parliament

**Triggers:**
- User invokes `/{hive-slug} parliament` or `/apiary parliament`
- (planned) Scheduled hourly CI job
- (planned) Threshold trigger: ≥50 `status: ready` files in `_inbox/`

**Behavior:** Follow the Parliament Operational Runbook in `protocol/custodian-workflow.md`. Summary: Sentinel scan → Archivist pre-processing (incl. cross-hive fit check) → route (fast path vs deliberation) → critics + Reviser + Chancellor → PR creation (incl. any cross-hive suggestions) → cleanup. Mis-filed contributions are only ever *suggested* to siblings, per the §2.1 step 5 direction guard.

---

## Audit

**Triggers:** User invokes `/apiary audit` or scheduled (configurable in `_custodian/config.yml`).

**Behavior:** Follow the Audit runbook in `references/mode-audit.md`. Summary: structural check → reference-library check → freshness check → learning loop health → version check → extension validity → Sentinel retrospective → generate report.

---

## Brief

**Triggers:** "Weekly summary," "what did we learn this week," "digest," or scheduled CI trigger.

**Behavior:**
1. Read current week's metrics log from `_metrics/`.
2. Read recent `_inbox/_completed/` entries to understand what was incorporated.
3. Read recent entries in the Hive's decisions knowledge file.
4. Synthesize a digest covering: new contributors, what was learned, what was rejected and why, what's escalated, knowledge base growth, staleness alerts from the most recent audit.
5. **Pattern detection → inbox stubs:** Analyze the week's activity for systemic signals and convert findings into inbox contributions — ranking gap findings from `_custodian/reports/loop-b-gaps.json` (count ≥ 2 first) rather than re-deriving them. Examples: N questions with no knowledge file coverage → `[process]` stub; recurring `[correction]` against the same fact → `[contradiction]` stub; workflow never invoked → `[meta]` stub; category exceeding Loop C (Calibration) approval threshold (`PROTOCOL/learning-loops.md`) → `[meta]` stub proposing triage policy relaxation.
6. Format as a human-readable briefing.
7. Optional: push to configured Slack channel (if Signal bot configured) or write to `_custodian/reports/brief-YYYY-WNN.md`.

---

## Deposit

**Triggers:** "Deposit this transcript," "store this source," "add to sources," "here's the meeting transcript," explicit deposit intent for primary source material.

**Behavior:** Follow the Deposit Path in `PROTOCOL/sources-policy.md`. Summary: route by format (binary documents → `/extract:ingest`; verbatim text/markdown → native path) → validate it's verbatim, not a summary → write to `sources/{doc-type}/` with frontmatter → append a row to `sources/index.md` (completion gate, Goal 9) → Sentinel scan → direct push → offer to extract learnings into the inbox. Deposits bypass Parliament (sources are ground truth) and require explicit user intent — only the optional learning-extraction step follows the autonomous cross-cutting discipline.

---

## Hive-Local Workflows (Extensions)

The seven above are upstream and present in every Hive. A Hive may add its own **named,
invokable** workflows — a recurring report, a domain-specific review — by declaring
`extensions.workflows` in `hive.yml`. Operate mode's Merge Extensions step merges them into the dispatch table,
so they route like any upstream workflow.

Extensions are **additive**: they add dispatch rows, never remove or override the seven. When an
extension's triggers overlap an upstream workflow (most often **Brief** or **Status**), the
extension's disambiguation prose decides; if it doesn't resolve the ambiguity, ask the user.

To author one, see `references/authoring-workflow-extensions.md`. Workflow extensions are
PROTOCOL files — changes go through a CODEOWNERS PR, not the inbox.
