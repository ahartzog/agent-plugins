---
layer: PROTOCOL
type: design-goals
description: "North star principles for all Hive Minds governed by the Apiary"
last_updated: 2026-04-16
codeowners: (read from hive.yml)
---

# Design Goals

These principles govern all decisions about how the Hive Mind is built and maintained. When trade-offs arise, return here.

---

## 1. Reference, Don't Duplicate

The knowledge base is an **index layer**, not a content repository. Knowledge files contain curated summaries (1-3 sentences per topic), descriptive links to authoritative sources, temporal annotations (`[learned:]`, `[review-by:]`, `[superseded:]`), and confidence scores. They do not contain full document reproductions, CUI content (path reference only), or speculative claims without a confidence tag.

**Do:** Link to the Confluence page, Jira board, or git repo with a one-line summary and `[learned:]` annotation.

**Don't:** Copy-paste the content of external documents into knowledge files.

**Why:** Duplicated content decays the moment the source changes. A stale copy is worse than no copy — it actively misleads.

**Enforcement:** Knowledge files have a 200-line budget. Exceeding it triggers extraction — move content to the source system, replace with a pointer. Reference-library files are thin routing indexes over `knowledge/`; external material is reached through a `type: index` catalog that declares its store root, not through raw URLs scattered in routers (see `protocol/knowledge-schema.md` § Reference Library Entry Format and § Store Roots for `type: index` Catalogs).

**The obligation this creates.** Choosing not to duplicate canonical documents means choosing to *reach* them instead. A Hive that indexes but cannot retrieve has not avoided duplication — it has traded a stale copy for no answer at all. This extends Goal 9: content that cannot be *found* misleads by omission, and content that is found but cannot be *opened* misleads the same way, because the reader cannot tell "the Hive has nothing on this" from "the Hive knows exactly where this is and could not fetch it." So indexing and retrieval are one capability, and both are held to a standard:

- **Indexing must be precise enough to act on.** A pointer that names a store but not a resolvable location is an anecdote, not an index entry. Catalogs declare a store root; rows resolve against it.
- **Retrieval is a first-class step of routing, not a fallback.** When an entry points at a document the question requires, the agent opens it — the same way it would read a local file. `protocol/routing-protocol.md` §Resolve and §Extract define how.
- **Unreachable is a reportable defect.** A locator that will not resolve, or a store whose tool is absent, is recorded as a routing gap (§On no match) — never papered over with a summary.

This is why the Hive can stay small without getting worse: the index is the whole product, so the index has to work.

---

## 2. Progressive Discovery via Descriptive Links

Links must be descriptive enough that a reader can decide whether to follow them without clicking. A link like "Architecture doc" is not sufficient. A link like "GTN System Design — event-driven ingest pipeline, gRPC interfaces" gives the reader enough context to route themselves.

This pattern serves three populations equally:
- Engineers who want a quick answer (the summary is enough)
- Engineers who need deep context (the link gets them there)
- **Agents answering a question** — for which "decide whether to follow without clicking" *is* the decision of whether to fetch the artifact. A description good enough for a human to skip the click is good enough for an agent to answer from; one that only gives an address tells the agent to go open it (`protocol/routing-protocol.md` §Extract).

The agent case is why a weak description costs more than reader inconvenience: it either forces a fetch that was not needed, or invites an answer that should have been a fetch.

---

## 3. Classification Discipline

Each Hive declares its maximum authorized classification in `hive.yml`. Content above the ceiling is always prohibited; content at or below is permitted when markings are correct. The principle is *discipline*, not *exclusion*.

Full model (two operating modes, marking requirements, enforcement layers, remediation runbook): `PROTOCOL/security-policy.md`.

---

## 4. Collective Ownership

The Hive Mind belongs to the team, not to any individual. This has structural implications:

- Every change to `knowledge/` lands through a PR — never a push direct to master. Two legitimate PR paths exist:
  1. **Agent path (Parliament):** Sessions write to `_inbox/`. Parliament triages and opens PRs against `knowledge/`. Fast-path categories auto-merge; deliberation categories require CODEOWNER sign-off.
  2. **Human path (direct PR):** A contributor who wants to author or ingest content themselves — a finished summary, a wholesale external doc, a deliberate restructure — may branch, edit `knowledge/` directly, and open a PR. **These PRs always require CODEOWNER review before merge**, regardless of size or category. Human judgment replaces Parliament's critic loop; the gate is not removed, only relocated.
- The inbox is the low-ceremony route for capture-in-flight. The direct PR is the higher-effort route for deliberate authoring. Neither bypasses quality control — they route to different reviewers.
- Autonomous agents use the inbox path only. Agents must not open PRs that modify `knowledge/` directly; that surface is reserved for humans acting with intent.
- The Parliament is a council of agents — no single agent has authority; the collective signal determines the outcome.
- Corrections must reach the shared knowledge base (not just one person's memory) to benefit everyone.

Individual contributors may maintain a personal layer (see `references/external-retrieval-caching-design.md` for the read-time cache design), but the shared layer is the primary knowledge surface.

[learned: 2026-04-19]

---

## 5. Contribution Flywheel

The Hive Mind only gets better if people use it and contribute back. The design must minimize friction at every step:

```
Contributions (inbox) → Parliament triage → Knowledge base → Better answers → More contributions
```

Each turn of the flywheel:
- Sessions contribute facts via inbox (low friction — append only, no review gate)
- Parliament processes contributions into shared knowledge (automated where possible)
- The knowledge base grows, giving the agent better grounding
- Better answers drive more usage and more contributions

**Design implication:** Anything that adds friction to the contribution step kills the flywheel. The inbox must be as easy to write to as possible. Quality gates live downstream (in Parliament), not upstream (at write time).

---

## 6. Size Budgets

| File Type | Target | Action if exceeded |
|---|---|---|
| Knowledge file | < 200 lines | Extract content to vault/repo, replace with pointers |
| PROTOCOL files | < 300 lines | Split into focused sub-files |
| Agent definition | < 300 lines | Move reference content to knowledge files |

These limits are not arbitrary. They're a forcing function for the "reference, don't duplicate" principle. A knowledge file that needs 400 lines is a knowledge file that has accumulated content that belongs elsewhere.

---

## 7. Temporal Annotations

Every fact in the knowledge base must carry provenance. No undated assertions. [learned: 2026-04-16]

- `[learned: YYYY-MM-DD]` — when the fact entered the system
- `[review-by: YYYY-MM-DD]` — required for `decay: fast` facts
- `[superseded: YYYY-MM-DD, reason]` — for facts that were once true but have changed

The Parliament Archivist enforces this. Contributions without temporal annotations are rejected or annotated before merge.

---

## 8. Upstream Governance

The Apiary governs all Hive Minds. Protocol improvements here benefit every child Hive. Changes to PROTOCOL/ files must be made at the Apiary level and propagated to child Hives — never patched directly in an individual Hive's PROTOCOL/ layer.

---

## 9. Discoverability Guarantee

Every artifact in the Hive — knowledge file, source deposit, reference — must be reachable by agents performing Ask or Audit. Content that exists but cannot be found is wasted content; it misleads by omission (users assume "no answer" means "no information").

**Mechanism:** The reference-library and source indexes form the discovery layer. Any new content surface (like `sources/`) must have a corresponding index that the Ask workflow can consult. Deposit and contribution workflows are responsible for maintaining index entries as a completion gate — the artifact is not "deposited" until it is indexed.

**Audit enforcement:** Audit checks for orphaned files (present in a directory but absent from its index). Orphaned files are flagged as discoverability gaps.

**Design implication:** When adding a new directory, file type, or content surface to the Apiary:
1. Define its index (where does the discovery entry live?)
2. Define the write path (which workflow maintains the index?)
3. Define the audit check (how does Audit detect orphans?)

If you cannot answer all three, the surface is not ready to ship.
