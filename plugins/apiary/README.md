# Apiary — the Hive Parent Protocol

**A governed, multi-contributor knowledge base that an AI agent operates — backed by nothing but a git repo, markdown, and bash.**

One upstream plugin (this one — the **Apiary**) carries the entire operating protocol. Any number of child repos (**Hives**) carry only their domain knowledge. Thirty-plus teams can each run their own Hive, and a routing improvement, security pattern, or triage fix lands upstream **once** and reaches every Hive on its next session — no vendoring, no sync scripts, no forks.

```
# Install                          # Use
claude plugin install apiary@ahartzog
/apiary create        # scaffold a new Hive
/your-hive            # talk to an existing one (its thin skill delegates here)
/apiary parliament    # incorporate accumulated contributions
/apiary audit         # health check
```

> **Reading guide.** New to this? Read the next three sections — they're the whole idea. Building on it, or you're an LLM operating a Hive? Jump to [The Protocol Contract](#the-protocol-contract-for-llms-and-protocol-authors). Debating where decisions happen? [Where Decisions Actually Get Made](#where-decisions-actually-get-made) is the map.

---

## The idea in one story

Your team's knowledge lives in twelve heads, four wikis, and a SharePoint nobody trawls. A new engineer asks "how does flight dynamics hand off to T&C?" and the answer is a shrug plus a link to a stale page.

A **Hive** fixes this with three moves:

1. **Anyone talks to the Hive's agent; the agent answers only from curated, cited knowledge** — and when it can't, it says so *and files the gap against itself* so the miss is repaired instead of repeated.
2. **Everything anyone learns gets captured for free.** During any session, new facts are appended to an inbox — no forms, no permission, no PR to write. Capture costs the contributor nothing, which is the only price at which capture actually happens.
3. **Nothing enters the shared knowledge without review.** A tribunal of AI agents (**Parliament**) triages the inbox: trivially-safe additions merge automatically; anything that modifies, contradicts, or opines goes through adversarial critics and a verdict — with humans holding the gates that matter.

Capture is frictionless, curation is ruthless, and the two never share a gate. That separation is the whole design.

## The architecture

```mermaid
flowchart TB
    subgraph APIARY["APIARY (this plugin — upstream, shared by all Hives)"]
        direction LR
        P["protocol/*.md<br/>routing · triage · security ·<br/>learning loops · schemas"]
        M["modes<br/>create · operate ·<br/>upgrade · audit"]
        A2["assets<br/>JSON schemas · templates ·<br/>Sentinel hook generator"]
    end

    subgraph H1["Hive: widget-integration (git repo)"]
        direction LR
        K1["knowledge/<br/>+ reference-library"]
        I1["_inbox/"]
        Y1["hive.yml<br/>persona"]
    end
    subgraph H2["Hive: platform-ops (git repo)"]
        direction LR
        K2["knowledge/"]
        I2["_inbox/"]
        Y2["hive.yml"]
    end
    subgraph H3["Hive: …30+ more"]
        direction LR
        K3["knowledge/"]
        I3["_inbox/"]
        Y3["hive.yml"]
    end

    APIARY -. "protocol loaded at runtime<br/>(never copied into children)" .-> H1
    APIARY -.-> H2
    APIARY -.-> H3
```

Three layers, strictly separated:

| Layer | Owns | Changes via |
|---|---|---|
| **Apiary** (upstream) | All mechanics: routing protocol, Parliament, Sentinel, triage rules, schemas, audit | PR to this plugin — one change reaches every Hive |
| **hive.yml** | A Hive's identity: slug, remote, codeowners, classification ceiling, extensions | The Hive's codeowners |
| **Content** | Domain knowledge, persona, inbox, sources | The three-phase loop below |

Two properties make the upstream model safe:

- **Extensions are additive-only, structurally.** A Hive can add workflows, schema fields, triage categories, and pre-push gates — but a gate is *compiled in after* the Sentinel scan and its failure is terminal before any gate runs, so no child configuration can weaken an upstream control. A Hive can only raise its own bar.
- **Protocol ships by reference, never by copy.** The lesson that forced this: an earlier version copied the routing protocol into each Hive at create time, and it drifted into 3-step, 6-step, and 7-step variants in production. Protocol that ships by copy is protocol that forks.

## The three-phase loop

```mermaid
flowchart LR
    subgraph S["1 · SESSION (any user, any time)"]
        U["user asks /<br/>mentions a fact"] --> AG["Hive agent<br/>answers with citations"]
        AG --> W["writes _inbox/ entry<br/>autonomously, pushes"]
    end
    subgraph AC["2 · ACCUMULATION (zero coordination)"]
        W --> IN[("_inbox/<br/>unique filenames,<br/>append-only")]
    end
    subgraph PA["3 · INCORPORATION (Parliament)"]
        IN --> SEN["Sentinel scan<br/>(deterministic + judgment)"]
        SEN --> TRI{"triage"}
        TRI -->|"[link] [person] [tracker]"| FAST["fast path<br/>auto-merge batch PR"]
        TRI -->|"everything else"| DELIB["deliberation<br/>tribunal"]
        FAST --> KN[("knowledge/")]
        DELIB --> KN
    end
    KN -. "better answers → more usage<br/>→ more contributions" .-> U
```

The contributor experience: *you talk to the agent; everything else is invisible until it needs a human.* Sessions never write `knowledge/` — a protocol invariant reinforced by tooling: the settings template pre-approves only `_inbox/`/`sources/` staging, and `knowledge/` changes arrive via Parliament PRs (or human direct-PRs), codeowner-gated wherever branch protection is configured.

**Where the inbox rides is configurable** (`hive.yml.inbox_transport`), and new Hives default to the **queue-branch transport**: sessions push to a dedicated, never-PR-gated queue branch, Parliament is the only bridge, and processed entries are drained from the queue after their attribution is preserved in `_inbox/_completed/`. That lets the default branch carry full vanilla protection — required PR + codeowner review on *everything*, no bots — while capture friction stays identical (one direct push): unreviewed content never enters default-branch history, and queue history can be cheaply rewritten for incident response. The legacy `default-branch` transport (inbox commits pushed straight to the default branch) remains available, and is what an absent field means — existing Hives never change transports without an explicit `hive.yml` edit; audit offers the migration. Design and migration: `skills/apiary/references/inbox-transport-design.md`.

## How a question finds its answer (the RLDP)

Retrieval is **LLM-navigated indexes over grep** — no embeddings, no vector DB, by design (contributors need nothing beyond git; and 2025-26 research has since validated plain-index navigation as the *better-performing* choice at this scale, not just the cheaper one). The Reference Library Discovery Protocol (`protocol/routing-protocol.md`) is the canonical spec; this is its shape:

```mermaid
flowchart TB
    Q["question"] --> D["Discover: glob every<br/>reference-library.md"]
    D --> F["Filter: read ## Scope<br/>headers ONLY (token-cheap)"]
    F --> M2["Match: trigger keywords"]
    M2 --> PR2["Prefer: rank candidates —<br/>authority · question-type · date<br/>(dates sorted mechanically, never 'judged')"]
    PR2 --> SUF{"sufficiency<br/>verdict (stated)"}
    SUF -->|"insufficient — e.g.<br/>recency-shaped question<br/>(Augment)"| SRCH["Search: scoped subagent<br/>queries the live store"]
    SRCH --> PR2
    SUF -->|sufficient| R["Resolve: locator → content<br/>(local file · URL · store-root join)"]
    R --> E["Extract: only what the<br/>question needs (grep catalogs,<br/>never read them whole)"]
    E --> ANS["Answer: cite the document,<br/>name its authority tier"]
    M2 -->|"no match but<br/>scope matched (Miss)"| SRCH
    SRCH -->|"nothing opened /<br/>declined / no tool"| NM["On no match (REQUIRED):<br/>answer flagged ungrounded +<br/>file the gap as a contribution"]
    M2 -->|"no match,<br/>no scope match"| NM
    NM --> ANS
```

Two ideas here are unusual and load-bearing:

- **A miss is a contribution.** `§On no match` makes gap-recording a *hard completion gate*: a question the index can't route becomes an inbox entry naming the gap. The routing index is repaired by its own failures.
- **The corpus is never assumed complete.** A catalog of an external store is a point-in-time view of something that keeps being written to — so a routing *hit* doesn't end the protocol; a sufficiency test does, and a recency-shaped question can dispatch a live, scoped store search whose discoveries are promoted (only if actually opened) into the catalog for every future session.

## Where decisions actually get made

The question every governed-knowledge system must answer: *who decides, who deconflicts, who resolves?* Apiary's answer is a **ladder of escalating authority** — evidence rules first, tribunal verdicts second, humans last and least often, with every decision recorded where the next reader will find it.

| Decision | Made by | Mechanism | Recorded as |
|---|---|---|---|
| Which source answers a question | Session agent | §Prefer: authority tier (`formal>baseline>delivered>working`) + question type + mechanical date sort | citation + authority named in the answer |
| Is the corpus sufficient | Session agent | §Sufficiency test (verdict stated in-transcript) | `sufficiency:` line |
| What enters the inbox | **Nobody** — capture is ungated | append-only, autonomous | attributed, timestamped entry |
| Is a contribution safe | Sentinel (deterministic scan + rules) | patterns + classification ceiling; **cannot be disabled by anyone** | quarantine + report |
| Is a contribution true/placed/formatted | Three parallel critics (Skeptic·Archivist·Cartographer), no cross-talk | independent PASS/FAIL checklists | checklists in the PR |
| Does it merge | **Chancellor** (verdict: MERGE/REVISE/REJECT/ESCALATE) | weighs critics; verifies directly on critic deadlock | verdict + reasoning in the PR |
| Conflicting facts over time | **Loop D** | 2nd challenge in 30 days → fact marked `[disputed:]`, humans summoned | `[disputed:]` annotation + needs-review PR |
| Anything an agent chose autonomously | Humans, eventually | `[decided: claude, date]` marks agent forks; audit surfaces unratified ones | `[decided:]` annotations |
| Protocol itself, escalations, disputes, `[meta]` | **Humans (codeowners)** — always | CODEOWNER-gated PRs; `[meta]` reaches humans regardless of verdict | PR review record |

Three principles under the table: **facts are never deleted, they're superseded** (`[superseded:]` keeps the losing fact visible under its marker — history is the audit trail); **disagreement is data** (a contradiction doesn't overwrite — it accumulates until velocity triggers escalation); and **agents propose, structure disposes** — no single agent, including the Chancellor, can put content into `knowledge/` outside a PR whose gates are set by humans.

---

## The Protocol Contract (for LLMs and protocol authors)

Dense summary. The files are canonical; this is the map.

**Invariants (hold every session, no file read needed):** never store content above the Hive's classification ceiling · every correction and reusable artifact becomes an inbox contribution before session end · cite knowledge sources · sessions never write `knowledge/` or `PROTOCOL/` · Sentinel cannot be disabled.

**File map:**

| Surface | File | Contract |
|---|---|---|
| Mode router | `skills/apiary/SKILL.md` | thin dispatch: create/operate/upgrade/audit; ≤150 lines by rule |
| Runtime | `references/mode-operate.md` | Step 0 one-call startup (clone/sync/hook/identity), lazy protocol table, push discipline |
| Routing | `protocol/routing-protocol.md` | the RLDP: 10 named steps (§Discover→§Answer); cite steps by name, never number |
| Retrieval metadata | `protocol/document-quality.md` | `doc_type`/`authority`/`covers`; trawling gates; question-type routing |
| Schema | `protocol/knowledge-schema.md` + `assets/*.schema.json` | frontmatter contract; inline annotations `[learned:] [decided:] [superseded:] [disputed:]`; store roots for catalogs |
| Triage | `protocol/triage-policy.md` | tag→path table; § Write Operations (ADD/SUPERSEDE/ANNOTATE — no DELETE); canonical MERGE disposition defers to custodian §4.3 |
| Parliament | `protocol/custodian-workflow.md` | Sentinel §0 (deterministic scan is a literal command) → normalize → Archivist → critics ∥ → Reviser → Chancellor → PRs → telemetry §6.2 |
| Security | `protocol/security-policy.md` + `protocol/sensitive-data-patterns.md` + `assets/generate-hook.sh` | layers L0 pre-push hook / L1 session redaction / L2 pre-receive (optional) / L3 Parliament; patterns JSON compiles into the hook; excerpt-bound overrides; classification findings non-overridable |
| Learning | `protocol/learning-loops.md` | A Correction, B Discovery (capture+findability are ONE obligation), C Calibration, D Escalation; A/B fire in-session, C/D in Parliament |
| Search | `protocol/external-search-agent.md` | §Search subagent contract: reads to dedup, writes nothing, returns catalog-shaped rows, never citable prose |
| Sources | `protocol/sources-policy.md` | verbatim primary material; Sentinel-gated, Parliament-bypassing; indexed or it didn't happen (Goal 9) |
| Tests | `skills/apiary/tests/` | 7 bash suites + `tests/golden/cases.md` — behavioral cases pinning RIGHT/WRONG with the governing protocol clause cited |

**Design goals that adjudicate disputes** (`protocol/design-goals.md` + repo `DESIGN-GOALS.md`): reference-don't-duplicate (the index is the product, so retrieval is an obligation, not a fallback) · progressive discovery · additive-only extensions · Sentinel non-negotiable · contribution flywheel (friction at capture kills everything downstream) · size budgets · temporal annotations on every fact · upstream governance · discoverability guarantee (every surface names its index, write path, and audit check — or it doesn't ship) · operating instructions carry no state or history.

**Authoring rules an LLM editing this repo must follow:** run the 7 test suites before any PR (`CLAUDE.md`); routing-file changes additionally run the golden behavioral half; every mechanical change passes the three CONTRIBUTING scenarios; cite protocol sections by §name; put rationale in `references/*-design.md`, never in hot-path files; state a Design-Goals compliance section in the PR.

---

## Classification Model

Each Hive declares its maximum authorized classification in `hive.yml`:

```yaml
classification:
  max_level: CUI             # UNCLASSIFIED | FOUO | CUI
  marking_required: true     # enforces frontmatter + in-body banner discipline
  storage_tier: "ghe-cui"    # documentation-only reminder of hosting requirement
```

Omitting the block defaults to `UNCLASSIFIED` with no marking discipline — the pre-v1.1 "reject all classified content" posture. Declaring a higher ceiling permits classified content at or below that level, provided:

- Every knowledge and inbox file carries a `classification:` frontmatter field.
- Files containing content above UNCLASSIFIED carry a matching banner (e.g. `CUI`) as the first line of the body.
- Unmarked classified content is quarantined by Parliament Sentinel.
- Content above `max_level` is always rejected, regardless of markings.

The Apiary does not verify that the hosting storage tier matches the declared ceiling — that's the operator's responsibility. See `skills/apiary/protocol/security-policy.md` for the full defense-in-depth model, including the two operating modes (UNCLASSIFIED-reject vs. classified-require-markings) and the per-layer enforcement details.

---

---

## Operator Reference — Standing Up a New Hive's Backing Store

> This section describes the *sanitized example environment* (fictional `meridian`/GHE hosts). Adapt org names, provisioning flow, and the Slack bot to your own environment; the sequence and gotchas are the transferable part.

`/apiary create` scaffolds all of a Hive's *files* (hive.yml, PROTOCOL, knowledge/, etc.) locally, but it does **not** create the GHE repo those files get pushed to, invite Signal to Slack, or configure repo-level access control. Those are one-time, human/repo-admin steps that must happen **before or immediately after** `/apiary create` — agents should walk the user through them explicitly rather than assuming they're already done. This section is the checklist for both.

### 1. Decide the classification ceiling first — it determines which org the repo lives in

Pick `hive.yml.classification.max_level` (Q5.5 of the create interview) *before* creating the repo, because it dictates which GHE org the repo must live in:

| Ceiling | GHE org | Example |
|---|---|---|
| `UNCLASSIFIED` (default) | `meridian/*` — standard org, broadly readable | `platform-navigator-hive` |
| `CUI` (may also carry ITAR content) | A restricted org whose access model matches the classification — e.g. `restricted-org/*`, `vault-org/*` — non-US/international contributors may lack access | `restricted-org/vault-hive` |

**If you want to hold CUI/ITAR content, the repo must be created in a restricted org, not `meridian`.** `restricted-org` is not the only acceptable choice — other restricted orgs (e.g. `vault-org`) may also be appropriate depending on program and access requirements. The Apiary does not verify or enforce this — Sentinel scans content, but it cannot check which org a repo lives in. Before creating the repo, **confirm with the user which org matches their classification ceiling and program** rather than assuming `restricted-org` by default. Getting this wrong means CUI-marked knowledge sits in a repo with the wrong access model. See `skills/apiary/protocol/security-policy.md` § Classification Discipline for the full marking-discipline rules once the ceiling is set, and Meridian Systems' data-classification / CUI-ITAR-authorization policy (`docs.meridian.example/dev/ai/security/cui-itar-authorization`) for the underlying obligation — repo placement doesn't relieve you of it.

Never put classified content in an UNCLASSIFIED-ceiling Hive "temporarily." If you're not sure which org a Hive belongs in, ask before creating it.

### 2. Create the GHE repo via `meridian/owners`

Meridian Systems repos are provisioned centrally through the `owners` repo, not by clicking "New repository" on GHE. Add an entry to `repos.yml` in the `owners` repo for the org you confirmed above (`meridian/owners` for UNCLASSIFIED; the matching restricted org's `owners` repo, e.g. `restricted-org/owners`, for CUI/ITAR) and open a PR — the `repo-provisioner` CI pipeline creates the actual GHE repo once it merges.

Full steps and the `repos.yml` schema: **[docs.meridian.example/dev/workflows/software-repo/create-a-repo](https://docs.meridian.example/dev/workflows/software-repo/create-a-repo)** (fetch via the `developer-docs` skill). A live example entry: [meridian/owners repos.yml](https://ghe.meridian.example/meridian/owners/blob/master/repos.yml).

Once the repo exists, run `/apiary create`, answer the interview (Q5.25 asks for exactly this repo's git remote URL), and push the generated scaffold to it.

### 3. Set up Signal (Slack notifications)

Signal posts PR/inbox activity to the Slack channel named in `hive.yml.slack_channel` / `.signal/config.yml` — but it will not post anywhere until it's actually invited to that channel:

1. In the target Slack channel, invite the Signal app: search for **"Signal"** in the channel's app directory and click **Add**.
2. Confirm `.signal/config.yml` (generated by create mode) has the right channel name — no leading `#`.
3. **Merge the config to the default branch.** Signal reads `.signal/config.yml` from `master`/`main` only; it will not notify on the PR that itself introduces the config.

Full reference: [docs.meridian.example/dev/workflows/release-management/release-notes/slack-pr-notifications](https://docs.meridian.example/dev/workflows/release-management/release-notes/slack-pr-notifications) — "Slack PR Notifications in Signal v3." Troubleshooting/questions: [#sw-signal](https://go.meridian.example/sw-signal).

### 4. Set codeowners correctly

`hive.yml.codeowners` (Q4 of the create interview) must actually match who can approve merges on the repo — the Apiary only writes the *intent*, it doesn't wire up GHE-side enforcement:

- **`push_mode: direct` (default):** no repo-side gating is required — the session agent pushes straight to the default branch. Still keep `hive.yml.codeowners` accurate; it's who Parliament tags for escalations and quarantine review (see `protocol/triage-policy.md`).
- **`push_mode: pr`** (required once the default branch has required status checks or policy-bot): codeowners enforcement moves to `.policy.yml` + a narrowed `CODEOWNERS` file, *not* GHE's native all-or-nothing CODEOWNERS check. Follow `skills/apiary/references/push-mode-pr-setup.md` § One-Time Operator Setup end-to-end — it covers enabling auto-merge, the required CI checks, the policy-bot rules that let `_inbox/**` auto-merge while `knowledge/**` stays gated on a codeowner, and the `CODEOWNERS` narrowing that's easy to miss (`_inbox/` must be listed with a blank owner list, or the native GHE check still blocks inbox-only PRs).
- For a first rollout on sensitive content (e.g. a new CUI Hive), consider requiring codeowner review on *every* PR — including inbox-only ones — until you've built confidence in Sentinel + Parliament. `vault-hive` did this for its first ~month; see its README's "Trial Period" note for the pattern.

### Order of operations, end to end

1. Decide classification ceiling → pick GHE org.
2. Create the repo via an `meridian/owners` (or `restricted-org/owners`) PR.
3. `/apiary create` → answer the interview → push the generated scaffold to that repo.
4. Invite Signal to the Slack channel named in `hive.yml.slack_channel`; merge `.signal/config.yml` to the default branch.
5. If using `push_mode: pr`, complete the one-time policy-bot / auto-merge / CODEOWNERS setup in `push-mode-pr-setup.md` before flipping the mode on.
6. Register the child skill in claude-clams (see Create mode Step 8) so `/your-hive-slug` is installable.
