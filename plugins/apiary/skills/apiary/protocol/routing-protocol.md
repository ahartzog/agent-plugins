---
layer: PROTOCOL
type: routing-protocol
description: "Canonical Reference Library Discovery Protocol — how the Ask workflow maps a question to the right knowledge file. Upstream-owned; child Hives supply only the routing table."
last_updated: 2026-08-03
codeowners: (read from hive.yml)
---

# Reference Library Discovery Protocol (RLDP)

The **canonical, upstream-owned** mapping from question to knowledge. Child Hives own only their
routing table (`PROTOCOL/agent-definition.md`) and their reference-library entries; a persona
references this protocol rather than restating it (an inline copy is superseded —
`references/mode-upgrade.md` § "Persona migration: adopt the upstream RLDP"). Design rationale for
every step lives in `references/external-retrieval-design.md` and
`references/external-retrieval-search-design.md` — read those when *changing* this file, not to
execute it.

**Runs on every Ask**, after consulting the routing table — not only when the table misses: a
routing hit does not establish sufficiency. Cite steps by name (`§Resolve`, `§On no match`) —
names survive renumbering. Material the Hive indexes but does not hold — a document in SharePoint,
Box, Quip, Confluence, Jira, or a git host — is **retrieved, not paraphrased**.

## The Protocol

1. **Discover** — `Glob("knowledge/**/reference-library.md")`. Never hardcode one path: flat Hives
   keep one library at the root, nested Hives one per subdomain, and a hardcoded path silently
   misses the others.

2. **Filter** — read each discovered library's `## Scope` header **only**; skip clearly unrelated
   files. Scope headers are what keep this step token-cheap; full bodies load only on relevance.

3. **Match** — scan relevant libraries' triggers (the `Triggers` column, or a `**Triggers:**` line
   in block form). A trigger matches if the question is a clear instance of the situation it
   describes.

   **Restate the query before scanning.** Triggers are written in the *author's* vocabulary; the
   question arrives in the *asker's*. Matching raw phrasing against raw triggers is keyword
   collision — and this is the step whose failure is most expensive, because a miss here ends the
   protocol before §Prefer, §Resolve, or §Extract ever run, and it fails **silently**: the output
   is an ungrounded answer, not an error. So first write 2–4 alternate phrasings on one line —
   synonyms, the document-vocabulary form, and any entity, system, or acronym names the question
   implies but does not say. Then scan triggers against the restatement set, not the raw question
   alone.

   > "who owns downlink scheduling?" → *ground segment ownership, downlink scheduler, pass
   > planning, CODEOWNER / ops responsibility*

   **This is restatement, not decomposition.** Do not split the question into sub-questions, do not
   generate a hypothetical answer document to match against, and do not run a separate retrieval
   pass per phrase. Those cost more than the fetch economy returns (`references/external-retrieval-design.md`);
   one line, one scan. Record the restatement in §Answer's trace so the step is observable.

4. **Prefer** — whenever more than one candidate is in hand, narrow before spending a fetch — at
   **every** point a candidate set appears:

   | Candidate set | Rank on |
   |---|---|
   | Matched reference-library entries (after §Match) | triggers, topic, `covers` text, specificity — entries carry no `authority`, so the ranking below does not apply here |
   | Matched catalog rows (after §Extract's grep) | `authority`, `doc_type`, `source_org`, dates — the ranking below applies here |
   | Live search results (after §Search) | the same ranking, but **below** authored rows (inferred metadata is a guess about a document; a trawl was a look at one). Exception: recency — a search hit carries the document's live date and beats a row's trawl-time date. **Rank this set only — never re-run the sufficiency test on it** |

   **On the catalog-rows set, run §Search's sufficiency test before resolving anything, and state
   the verdict in one line** — `sufficiency: sufficient` or `sufficiency: insufficient — <which
   signal tripped>`. If it trips and §Search's bounds still allow a search for this store,
   dispatch now — **via §Search's pre-dispatch user prompt** — and rank its results with the rows
   in hand. If it trips but bounds disallow (store already searched, store cap reached, inside
   §Recurse), proceed with the rows and, if no opened document ends up answering, record per
   §On no match. The test is asked **once per store per question**.

   Rank by `authority`: `formal` > `baseline` > `delivered` > `working`
   (field semantics: `protocol/document-quality.md`). Apply question-type awareness:
   - Design ("how is X designed?") → prefer `baseline` or `formal`
   - Status ("what's the current state of X?") → prefer the most recent, regardless of authority.
     "Is X working *right now*" is different — probe the live system first (full table:
     `protocol/document-quality.md` § Question-Type Routing)
   - Requirements → prefer `formal`
   - Vendor ("what did Y deliver?") → prefer `delivered`, filter by `source_org` if present

   **"Most recent" means most recently *true*, not most recently *written*.** A status question
   asks about the world, so rank on `[effective: YYYY-MM-DD]` where a candidate carries it
   (`protocol/knowledge-schema.md` § Inline Annotations) and fall back to `[learned:]` /
   `last_updated` where it does not. The two clocks diverge in the case that matters most: a fact
   ingested today can describe a state from last quarter, and a fact written months ago can still
   be the current one. Ranking a backfilled note above the fact it describes is the failure this
   rule exists to prevent. Mixed candidate sets are normal — say which clock each winner was
   ranked on when they differ.

   **Freshness tiebreak.** When candidates are otherwise comparable — same `authority`, both
   responsive — prefer the one whose freshness posture is healthier: within its `decay` threshold
   (`protocol/knowledge-schema.md` § Decay Semantics) and not past `review_by`. If the winner is
   nonetheless stale, it still wins, but caveat it per §Answer's staleness rule rather than
   presenting it as current.

   **Execute the ranking on paper, not in your head:** lay the candidate set out as a compact
   table (`candidate | authority | date | why it might win`) and rank in one pass. **Recency is
   decided mechanically, never judged** — extract each candidate's date into an explicit list,
   sort it (piping the grepped rows through `sort` is fine), and name the newest *before*
   reasoning about content (why: `references/external-retrieval-design.md` § Why recency is
   resolved mechanically).

   Narrowing drops *redundant* candidates. A question spanning several `scope` values (a
   requirement, a design, the analysis behind it) legitimately needs more than one source.

5. **Resolve** — turn each preferred locator into content, dispatching on locator kind:

   | Locator kind | Looks like | How to resolve |
   |---|---|---|
   | **Absolute URL** (preferred form) | `https://…sharepoint.com/…`, `https://…quip.com/NieRAn8pvonB` | fetch with the tool serving that host (`protocol/tool-tiers.md` § Store Kind → Tool — consult only when needed) |
   | Local file (default inside `knowledge/`) | `program/overview.md` | `Read` it, relative to `knowledge/` |
   | Directory pointer | `people/profiles/` (trailing slash) | every `.md` beneath it, recursively |
   | **Hive-root path** — any locator whose first segment is `sources/` | `sources/index.md`, `sources/meeting-transcripts/2026-07-15-jrivera-sync.md` | `Read` it relative to the **Hive root**, not `knowledge/` |
   | Store-relative path | `06 - Ground Segment/ICDs/` | join to the store root the file's frontmatter `sources[]` declares, then fetch as an absolute URL |

   **Why `sources/` needs its own row.** `sources/` is a top-level directory *outside* `knowledge/`
   by deliberate design (`protocol/sources-policy.md`), and the router row that makes it reachable
   is prescribed verbatim by that policy as `sources/index.md`. Resolved under the default rule
   that row becomes `knowledge/sources/index.md`, which does not exist — so the Hive's
   highest-fidelity material was addressable but unreachable. Resolve `sources/…` from the Hive
   root; if that misses, retry once under `knowledge/` before declaring it broken (a Hive that
   happens to keep a `knowledge/sources/` directory still resolves, and the retry costs one `Read`).

   A store-relative row whose file declares no store root is unresolvable: treat it as a broken
   pointer and record it per §On no match (authoring rules: `protocol/knowledge-schema.md` § Store
   Roots). **When the tool is missing, degrade explicitly — never silently:** name the tool, give
   the resolved URL, offer the install (`protocol/tool-tiers.md` § Degradation Patterns), and
   record the gap per §On no match. Never answer from a stale local summary while staying quiet
   about the unopened document.

6. **Extract** — take only what the question needs from resolved content, local or fetched:
   - A `§ section` anchor → that section only.
   - Target has `type: index` (a document catalog) → do **not** read it whole; grep for rows
     matching the query terms — rarest, most distinctive term first, intersecting a second term
     when the hit set is large — and take only those rows plus the table header. Match on the
     `covers` column plus the document name; where a row carries no `covers`, matching is by
     filename only — say so rather than reporting a filename match as a topical one.
   - Otherwise → the whole document.

   **Fall through to the verbatim original when the wording *is* the answer.** A `knowledge/` file
   is a curated paraphrase; `sources/` holds the deposited original. When the question asks for
   exact wording, a committed value, requirement text, or who said what — "what exactly does the
   ICD say about X", "quote the decision", "what number did they commit to" — a paraphrase must not
   be quoted as though it were the source. Check `sources/index.md` (reachable per §Resolve's
   Hive-root row) or the answering file's own `sources:` frontmatter, and if a deposited original
   covers the topic, open it and quote from there, citing the source path. A binary source may need
   `git lfs pull` first; if it cannot be materialized, say so rather than quoting the summary as
   verbatim. **Where the source and the knowledge file disagree, the source wins** — and the
   divergence is a `[correction]` contribution with the source path as its evidence
   (`protocol/learning-loops.md` Loop A). Ordinary topical questions stay on the `knowledge/` path;
   this clause fires on the wording, not on the topic.

   **Fetch the artifact behind a pointer when the pointer is not enough** — when the entry or row
   does not answer (an address, filename, or metadata only), or the question needs depth a summary
   cannot carry (specific values, exact wording, a figure). A row's `covers` text can fully answer
   a scoping question ("which document defines X") — answer from it and cite the row; it never
   substitutes for the document when the question asks what the document *says*. When two sources
   would both answer, prefer the cheap one; a repeatedly-needed binary belongs in `sources/` via
   the Deposit path (`protocol/sources-policy.md`).

   **Promotion (a completion gate):** every document reached via §Search that was **opened** — by
   the search agent or by you, whether or not it answered — is promoted: write a `[link]` inbox
   contribution carrying the finished catalog row (content-derived `covers`, marked
   `discovered_via: search`, carrying `supersedes` for a newer revision, absolute URL preferred).
   **The session never writes the catalog itself** — Parliament appends the row on its fast path.
   Full rules, including the disproving-read and unopened-candidate cases:
   `protocol/learning-loops.md` § Loop B (Discovery).

7. **Recurse** — a resolved target may itself be routing rather than content: another
   `reference-library.md`, or catalog rows that are themselves locators. **Apply §Prefer to that
   new candidate set first**, then feed the winners back to §Resolve. Traverse one additional
   level; use judgment and stop when context is sufficient.

   **Where a traversal begins:** the first catalog reached from a matched reference-library entry
   is **not** a §Recurse traversal — grepping it is §Extract, and the sufficiency test runs on its
   rows (§Prefer). §Recurse begins at the level *beyond* that first catalog, and §Search never
   fires from inside it.

8. **Search** — widen the corpus with a live store query when a corpus hit is insufficient. Like
   §Prefer, a rule invoked on a judgment — not a sequential fallback. Two entry points:

   | Entry | When | Effect |
   |---|---|---|
   | **Miss** | routing produced no candidate, but a `## Scope` matched the domain | search is the only route; run it before §On no match |
   | **Augment** | routing produced candidates but completeness is doubtful | search runs before a fetch is spent; results join the candidate set at §Prefer |

   Augment is judged at §Prefer's catalog-rows set; Miss runs before §On no match; neither is
   reached by falling through §Recurse.

   **Sufficiency test — a corpus hit is insufficient when any of these holds** (state the verdict
   in one line at §Prefer):
   - a `type: index` catalog covers the store but no row matched the question;
   - the question is recency-shaped ("latest", "current", "did X land") — a catalog row's date is
     the document's date *as of the trawl*, so it structurally cannot say what is newest now;
   - the matched row is a folder-level pointer only (no document named);
   - the user explicitly asked to search.

   **Hard non-trigger (the false-grounding guard): if no `## Scope` matched any domain, do NOT
   search.** A store the Hive was never pointed at is out of bounds; searching it manufactures
   grounding the corpus does not have. Fall to §On no match instead.

   **Ask the user before dispatching** — effort tier, any location guidance, and authorization for
   tenant-wide scope (the default is the roots the covering catalog declares in `sources[]`).
   Subagents cannot prompt (`AskUserQuestion` is main-agent-only — `protocol/security-policy.md`
   Layer 0), so scope is settled before dispatch. **Bounds:** once per store per question; at most
   2 stores; **not re-entrant** — §Search MUST NOT fire from inside a §Recurse traversal.
   **Dispatch** as a subagent per `protocol/external-search-agent.md` — when the bounds permit two
   stores, dispatch both subagents concurrently; the searches are independent.

9. **On no match — record the gap (required).** Fires unless the question was answered from a
   document that was actually opened — whether routing found it or §Search surfaced it. A local
   knowledge file that was read counts as opened, and so does a scoping question fully answered
   from a row's `covers` text (§Extract) — those answers are grounded; do not flag them or record
   a gap. A matched trigger does not discharge this step, and neither does a search that ran; an
   opened document does. When it fires, do all three:
   - Answer from general knowledge, **explicitly flagged as ungrounded** — say the Hive has no
     knowledge file covering this.
   - Write an inbox contribution capturing the coverage gap, tagged `[process]` for a missing
     knowledge area (description starts `coverage-gap:`) or `[link]` when you can name the
     resource that should be indexed (description starts `routing-gap:`) — autonomously, per
     `protocol/workflows.md`; do not ask permission. The prefixes are what let Parliament mine
     gaps into Loop B telemetry.
   - If a knowledge file *did* answer but no reference-library entry pointed at it, that is a
     routing gap, not a knowledge gap: contribute a `[link]` entry proposing the row.

   Record the same way when routing reached an entry but the material stayed out of reach — a
   locator that would not resolve (no store root declared, dead link) or a store whose tool is not
   installed. Tag it `[link]`, description starting `unreachable:`, name the locator and what was
   missing. An unrecorded unreachable
   pointer is repaired by nobody. This step is the RLDP's contribution to Loop B (Discovery)
   (`protocol/learning-loops.md`).

10. **Answer** — first, two completion gates: (a) every document §Search surfaced that was opened
   has its promotion contribution written and pushed (§Extract owns the gate; this is its
   checkpoint at the step where sessions end); (b) §On no match has fired if no opened document
   answered. Then synthesize from the resolved sources: cite the source document, not just the
   library entry; include `authority` when relevant ("per the CDR baseline…" vs "per the working
   draft…"); when a document could not be reached, say so rather than implying the summary was the
   source. A document found by live search is cited as found-by-search, with why it was selected.
   **Never cite a search hit that was not opened.**

   **Warn the reader when a cited file is past due.** A stale copy read as current is worse than
   silence (`design-goals.md` §1). When a cited knowledge file is past its `review_by`, or its
   `last_updated` exceeds its `decay` threshold (`protocol/knowledge-schema.md` § Decay Semantics),
   append the posture inline to that citation — *per `ground-segment/architecture.md`
   (unverified since 2026-03-04)*. One parenthetical on the citation itself, not a separate
   caveat paragraph: the warning has to travel with the fact, because the fact is what gets quoted
   onward.

   **Close with the routing trace — one line.** End the answer with a compact record of how it was
   reached:

   ```
   trace: restated "downlink ownership, pass planning" | libraries 2/5 → matched 3 → sufficiency: sufficient
        → opened: ground-segment/architecture.md, sources/meeting-transcripts/2026-07-15-jrivera-sync.md
   ```

   Two rules make it load-bearing rather than decorative:
   - **Every citation in the answer must name a locator that appears in `opened:`.** A citation
     that does not is either a document that was never actually read or an invention — remove the
     citation or open the document. This is the cheapest citation-verifier available and it costs
     no extra call, since the opened list is already in hand.
   - **An empty `opened:` means §On no match must have fired.** The trace is where that gate
     becomes checkable instead of remembered.
   - **Omit a field the route never produced — never invent one.** A one-hop local answer reaches
     no catalog rows, so §Prefer's sufficiency test was never asked and the trace carries no
     `sufficiency:`; a question answered without restatement ambiguity may carry none. A trace that
     reports a verdict nobody reached is a fabricated observation, which is the exact failure the
     trace exists to make detectable. `opened:` is the only field required on every Ask.

   Keep it to one line — this runs on every Ask, so the trace is deliberately a line and not the
   step-by-step narration it could easily become. It exists to make the protocol observable: golden
   cases can assert on its structure, and the answered-from-opened ratio is what tells Loop B
   whether routing is improving or decaying (`protocol/learning-loops.md` § Telemetry).

## For contributors

Drop a `reference-library.md` with a `## Scope` header and entries into any `knowledge/`
subdirectory — §Discover finds it automatically; no registration needed. Entry format, size
budget, and the store-root declaration a catalog needs:
`protocol/knowledge-schema.md` § Reference Library Entry Format.
