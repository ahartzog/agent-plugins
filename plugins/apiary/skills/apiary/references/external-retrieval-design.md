# External Retrieval — Design Rationale

Why the RLDP resolves external locators the way it does. Companion to
`protocol/routing-protocol.md` (§Resolve, §Extract) and `protocol/knowledge-schema.md`
(§ Store Roots for `type: index` Catalogs). Loaded on demand — when someone asks why retrieval
works this way, or when changing it — not on every session.

---

## The obligation Goal 1 creates

Design Goal 1 says the knowledge base is an index layer that does not duplicate canonical
documents. That is a sound rule with an unstated consequence: if the Hive deliberately does not
hold the content, then **reaching the content is not an optional extra — it is the other half of
the product.** An index that cannot be resolved into an answer has not avoided duplication; it has
traded a stale copy for no answer. Goal 9 makes the same point about content that cannot be
*found*; unreachable-but-indexed content fails identically, because the reader cannot distinguish
"nothing here" from "known location, not opened."

Goal 1 now states this consequence explicitly, and the RLDP implements it. Retrieval sits at the
same level as reading a local file rather than being a fallback for when local files fail.

Two failure modes that framing rules out, and the reason the protocol states retrieval as an
obligation rather than a permission:

- **Silent under-answering.** Answering from a knowledge summary when the entry points at a document
  the question actually requires, without saying so. The reader has no way to tell a grounded answer
  from a summary that stood in for one. If the artifact is reachable, reach it; if not, name the
  document and say why it could not be opened.
- **Dead-ending on a pointer.** Reporting a catalog row ("the ICD is in `06 - Ground Segment/`") as
  though it were the answer. A pointer is an address, and an address is only an answer to "where is
  this" — §Extract is where that distinction gets made.

## Why Load split into Resolve and Extract

The predecessor step, `Load`, held three cases: a `§ section` anchor, a `type: index` catalog to
grep, and "otherwise the whole file." Those are not peers. Two of them decide **how much of a
document to read**; the third decides **what kind of thing the target is**. Because they sat in one
flat list, they read as mutually exclusive, and two real combinations could not be expressed:

- grep a catalog that lives in an external store
- load one section of a fetched document

Splitting the concerns fixes the inexpressiveness and puts growth on the data path:

| Concern | Step | Dispatches on |
|---|---|---|
| Turning a locator into content | §Resolve | locator kind (local file, directory, absolute URL, store-relative) |
| Taking the needed part of that content | §Extract | granularity (`§` anchor, catalog grep, whole) |

A new store kind is now a row in `tool-tiers.md` § Store Kind → Tool — data — instead of another
prose case in an always-loaded protocol file. Protocol that grows by prose edits is protocol that
forks (see `DESIGN-GOALS.md` Lessons Learned).

## Why absolute URLs are preferred, and store roots still supported

An absolute URL is the better locator on every axis that matters: it resolves with no surrounding
context, it survives being copied into an inbox entry or a chat message, and it is the *only* form
that works for the many stores addressed by opaque ID rather than by path — a Quip thread
(`/NieRAn8pvonB`), a Box file (`/file/123456`), a Confluence `pageId`, a Jira key. For those stores
"relative path" is not a concept and a store root buys nothing. So absolute is the preferred form,
and the expectation is that it becomes the common form as retrieval matures.

Store roots are nonetheless supported, for one narrow and currently-dominant case: a **hierarchical
document library** (SharePoint, OneDrive, Google Drive) where dozens of rows share a root and
per-row URLs would consume the budget the catalog exists to save. This is not hypothetical — the
existing corpus is overwhelmingly of this shape, because folder trawls produce folder maps, and
trawls were the only way to catalog a store nothing could resolve. Dropping support would make the
majority of already-written rows unresolvable, so §Resolve handles both and the schema states the
preference. Converting them is backlog cleanup, not a precondition.

A second consequence of the trawl origin: most store-relative rows name a **folder**, with the
filename in a separate `Document` column. Resolution is therefore root + location + document, and a
folder-level row resolves to a container the agent must then list. That is why folder-level rows are
legitimate but weaker — they answer "where does this class of document live" without being citable
as a document.

This also settles the store-discriminator question. For an absolute URL the host identifies the
store and a separate field would be redundant. For a store-relative row it does not:
`02.01 - Specifications` names no store. `type` therefore earns its place on the **root**, where the
ambiguity actually lives, and not on every row.

## Why the fetch decision belongs to the entry, not the tool

Two different questions are easy to conflate:

- *Can this be reached, and with what?* — mechanics. Stable across Hives. `tool-tiers.md`.
- *Should this be opened for the question at hand?* — a judgment about the material and the
  question. `routing-protocol.md` §Extract, informed by what the entry says about the document.

Putting the second in the tool table would make "how do I call SharePoint" and "is this document
worth opening" one setting, and would force per-Hive edits to a table whose mechanics are identical
everywhere. Keeping the tool table mechanics-only is what lets it stay upstream and shared.

## Why Goal 2 is the fetch gate

The decision §Extract has to make — *is what I have in hand enough, or do I need the artifact?* —
is the decision Goal 2 already describes: a link must be descriptive enough that a reader can
decide whether to follow it without clicking. An agent is a third population of that same rule, so
no new taxonomy was added; Goal 2 was extended to name it.

The practical test has two halves, because a good description can still be insufficient: the entry
may simply not answer (it gives an address or a filename), or the question may need depth a summary
cannot carry (exact values, requirement wording, a figure). Either sends the agent to the artifact.

This is also why a thin entry is more expensive than it looks. It either forces a fetch that a
better sentence would have avoided, or invites an answer that should have been a fetch.

## Why Prefer is a rule, not a stage

Selection is cheap; fetching is not. A SharePoint document costs auth, navigation, download, and
parse, and a large binary costs more. So narrowing has to happen before resolving — but *where* that
is possible depends on which hop you are on, and this is easy to get wrong.

Ranking needs `authority`, `doc_type`, `source_org`, and dates. Those live in **catalog rows**, not
in reference-library entries — an entry is `Topic | Source | Triggers`. So on the two-hop path
(router → catalog → document) the metadata does not exist in context until §Extract has grepped the
catalog. A Prefer that runs only once, before anything resolves, has nothing to rank on exactly when
it matters most: the external path this protocol exists to serve.

Ordering Prefer after Load would fix the two-hop case and break the one-hop case, fetching every
matched document before choosing among them. Both single positions are wrong because there are two
candidate sets, arriving at different times:

| Candidate set | Appears after | Rank on |
|---|---|---|
| Matched reference-library entries | §Match | trigger and `covers` specificity — entries carry no `authority` |
| Matched catalog rows | §Extract's `type: index` grep | `authority`, `doc_type`, `source_org`, recency |

Prefer is therefore written as a rule invoked at each set, and §Recurse applies it before feeding
rows back to §Resolve. Without that, a catalog hit resolves every matched row and the `authority`
column — the entire reason a catalog carries one — never affects what gets read.

The same cost reasoning is why §Extract prefers a cheap source when two would answer, and why a
repeatedly-needed binary belongs in `sources/` through the Deposit path: fetch-once-and-distill
amortizes what read-time fetch pays every session. Note the boundary — `/extract:ingest` accepts
local paths and Confluence URLs, so for other stores retrieval still happens first. Ingest
amortizes the parse, not the reach.

## Why recency is resolved mechanically

§Prefer requires dates to be extracted into an explicit list, sorted, and the newest named
*before* any reasoning about content. Delegating that comparison to in-context judgment fails in
two measured ways (arXiv 2606.01435, "Don't Ask the LLM to Track Freshness"): a strong training
prior about a familiar document overrides an explicit "newer wins" instruction, and serial
comparison drifts as the candidate set and context grow (the paper measures a +10.8pp average
accuracy gain for deterministic resolution, rising to +21pp at long context). The same reasoning
is why §Prefer ranks the whole candidate set laid out as a table in one pass rather than
candidate-by-candidate: serial evaluation is the drift condition. The instruction lives in the
protocol as a bare rule; this is the evidence behind it — and the citation to show the next
person who proposes trusting the model's sense of "newer."

## Why the sufficiency test sits on the catalog-rows set

Deferring the test until after §Resolve would spend a fetch on the catalog winner and then
discard it for a newer document surfaced by search — the one wasted fetch the placement exists to
prevent, on exactly the recency-shaped questions the augment path targets. Two of the test's four
signals ("no row matched", "the row is folder-level") presuppose grepped rows, so the earliest
point the test can run is where the rows first exist. It is asked once per store per question
because most of its signals are properties of the question, not the candidates — a recency-shaped
question stays recency-shaped after a search returns, so re-testing §Search's own output would
never terminate. (See also `external-retrieval-search-design.md` § Where the judgment is made.)

## Why unreachable is a recorded defect

An index entry that cannot be resolved is a routing defect, but it is invisible: the session that
hits it can still produce a plausible answer from the summary. Nothing downstream sees the failure,
because Parliament sees contributions and never the questions that failed. So §On no match covers
the unreachable case alongside the no-match case — the session is the only observer, which makes
recording it the session's obligation under Loop B (Discovery).

## Why there is no vector store, and what would change that

The RLDP retrieves by glob, trigger match, and grep. No embeddings, no index build, no vector
database. That was originally a **concession** — a Hive is a git repo that must work on a laptop
with bash and git, and standing up an index per Hive across 30+ instances was not affordable. The
concession framing is now out of date, and this section records why, because the first "let's add
a vector DB" proposal will otherwise be argued against a rationale nobody believes anymore.

The evidence that landed since:

- **Anthropic removed vector search from Claude Code in favor of grep-based agentic search** —
  measured as better on the code-retrieval task, not merely cheaper, and shipped as the default in
  a product where retrieval quality is the product.
- **"Is Grep All You Need?" and the agentic-search ablations** report parity-to-advantage for
  iterative grep-and-read against embedding retrieval on corpora in the low thousands of
  documents, with the crossover driven by corpus size rather than task difficulty.
- **~94.5% of full-RAG quality at zero infrastructure** is the repeatedly-measured figure for
  structured-index-plus-grep at this scale. The remaining ~5.5% is dominated by *paraphrase* misses
  — the asker and the author used different words for the same thing.

Two consequences for this protocol. First, vectorless is the **better** architecture at Hive scale,
not a compromise it tolerates; a proposal to add embeddings has to beat grep, not merely match it.
Second — and this is the actionable half — the known residual failure mode is paraphrase, which is
precisely what §Match's restatement step attacks and what a `covers` column on catalog rows
attacks. Those are the cheap interventions that buy most of the gap, and they need no index.

**The revisit trigger, stated so it is falsifiable.** Reopen this decision when **both** hold:

1. A single Hive passes roughly **1–2k indexed documents** — the scale at which the ablations put
   the crossover; and
2. `_custodian/reports/loop-b-gaps.json` shows recorded misses dominated by **paraphrase failures**
   (the asker's words never met the author's) rather than **coverage gaps** (the material was never
   indexed at all).

Condition 2 is the load-bearing one. A vector store fixes vocabulary mismatch; it does nothing for
material the Hive never indexed, and coverage gaps are what the telemetry has actually been
recording. Adding an index against a coverage-dominated gap profile would spend real infrastructure
on the wrong failure — so measure the profile before proposing the substrate.
