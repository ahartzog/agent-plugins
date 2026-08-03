# Live Store Search — Design Rationale

Why the RLDP searches a store it has already indexed, when it decides to, and how a search result
becomes a catalog row. Companion to `protocol/routing-protocol.md` (§Search, §Prefer, §Answer),
`protocol/external-search-agent.md` (the dispatch contract), and
`references/external-retrieval-design.md` (§Resolve / §Extract, which this extends). Loaded on
demand — when someone asks why search works this way, or when changing it — not on every session.

---

## The third indistinguishable failure

Goal 9 states the problem the Hive exists to avoid: content that exists but cannot be found
"misleads by omission — users assume 'no answer' means 'no information'." Goal 1's obligation clause
names the second instance: the reader "cannot tell 'the Hive has nothing on this' from 'the Hive
knows exactly where this is and could not fetch it.'"

There is a third member of that family, and it is the largest:

| Failure | What the reader is told | Closed by |
|---|---|---|
| Indexed, no route to it | "no information" | Loop B's indexing obligation |
| Indexed, not opened | a paraphrase of a summary | §Resolve / §Extract |
| **In the store, never indexed** | **"no information"** | **§Search** |

The third is indistinguishable from the first two at the point of consumption, and it is unbounded
in a way they are not. The first two are defects in a corpus the Hive controls, so they shrink as
the corpus is maintained. The third grows on its own: a catalog is a **point-in-time view of a store
that keeps being written to**. Every upload after the last trawl widens the gap, whether or not
anyone touches the Hive.

This is why the corpus can never be assumed complete. Not because trawls are done badly, but because
completeness is not a property a static index of a live store can hold. The protocol has to encode
"there is probably more" as a standing assumption rather than a failure state.

## Why search is not gated on no-match

The obvious shape — "if no trigger matched, search" — is wrong, and it is wrong in the direction
that matters.

A routing hit does not mean the corpus is complete for the question. It means the corpus has
*something*. For a question about current state, the catalog row that matched may be the stalest
possible answer: authored months ago, describing a document that has since been superseded by one
uploaded last week that no row names. Gating search on no-match makes the protocol *most* confident
exactly where it has *least* right to be — it searches when it found nothing, and stays quiet when
it found something old.

So §Search is not a fallback branch. It is invoked on a **sufficiency judgment**, at two points:

| Path | When | Effect |
|---|---|---|
| **Miss** | routing produced no candidate, but a `## Scope` matched | search is the only route to an answer |
| **Augment** | routing produced candidates, but completeness is doubtful | search runs before a fetch is spent; results join the candidate set at §Prefer |

The augment path is the one that addresses the actual operational complaint (a corpus whose
catalogs trail a store's write cadence), and it is the one a no-match gate would never reach.

This mirrors a decision the protocol already made. §Prefer is written as a rule invoked at each
candidate set rather than a stage in a sequence, because there are two candidate sets arriving at
different times (`external-retrieval-design.md` § Why Prefer is a rule, not a stage). §Search is the
same shape for the same reason: there are two moments at which the corpus can be judged
insufficient, and a step list that fixes one position gets the other wrong.

**Where the judgment is made, and why only once.** Two of the test's four signals — "no row
matched" and "the row is folder-level" — presuppose grepped rows, which exist only after a catalog
has been grepped; so the augment judgment belongs to §Prefer's catalog-rows set, not to the
reference-library-entry set that precedes it, and the verdict is stated where the rows are in hand. And the test is asked once per store, because most of its signals are properties of the
*question* rather than of the candidates — a recency-shaped question is still recency-shaped after a
search returns. A test that re-ran on §Search's own output would re-trip forever; the once-per-store
bound is what makes the rule terminate, so it is stated where the dispatch decision is made rather
than only in §Search.

## Why the cost argument does not carry over

§Prefer's cost reasoning — "selection is cheap; fetching is not" — was written about narrowing among
candidates before paying auth, download, and parse on a document, and it is correct there. Extending
it to forbid search conflates two operations with different cost profiles:

| Operation | Returns | Cost |
|---|---|---|
| **Search** | titles, paths, IDs, modification dates | one call, no download, no parse |
| **Fetch** | document bytes | auth + navigation + download + parse; a binary costs more |

A store search returns **catalog-shaped metadata**, which is the same shape §Prefer already ranks. It
is a selection operation, not a retrieval one. Placing it before §Prefer therefore *serves* the cost
model rather than violating it: it widens the candidate set with cheap metadata so the one expensive
fetch is spent on a better document.

The stronger point is amortization, and it is the same argument `sources/` already won. A search
whose result is promoted to a catalog row is paid **once**; the row answers every later session for
free. The pre-search behavior pays a different cost — an unanswered question — on **every** session,
forever, and never converges. Recording a gap and stopping is not the cheap option; it is the option
whose cost is invisible because nothing measures it.

## Why judgment is the hard part

A search hit is a **keyword match with no trust metadata**. The catalog fields §Prefer ranks on —
`authority`, `doc_type`, `covers`, `source_org` — do not exist on it. They are exactly what a human
trawl produces. So search widens the candidate set with the *weakest* candidates in the system, and
the risk it introduces is not cost but **false grounding**: an unrelated deck that happens to match
a keyword, cited with a URL, reads as better-sourced than an honest ungrounded answer. The citation
launders it.

Three guards, each aimed at one of the three judgments a search result requires:

- **Relevancy — infer metadata for *selection* only.** `protocol/document-quality.md` § Trawling
  Heuristics already specifies how to derive `doc_type` and `authority` from a path (a document
  number ⇒ `formal`; a `CDR/` folder ⇒ `baseline`; a vendor delivery folder ⇒ `delivered`). Search
  reuses it rather than inventing a parallel scheme. Inference is good enough to *rank a candidate*
  and never good enough to *describe a document* — so it ranks below authored metadata when both are
  present, and it never reaches the corpus (see § Why promotion requires a read).
- **Timeliness — search is better here than the corpus.** Most store searches return a modification
  date in the hit payload, so recency ranking works on live results and works *better* than on catalog
  rows, which carry the trawl's date rather than the document's current state. Stores differ in how
  much of the ranking they will do — some order by date, some only filter, some neither
  (`protocol/tool-tiers.md` § Store Kind → Tool) — and `ghe`/`gitlab` differs on the other axis too: a
  `src search` hit carries no date at all, so recovering one costs a follow-up `git log -1` call, paid
  only for hits that already cleared the relevance bar. The limit worth naming beyond that: a store
  that cannot order by date cannot be asked for the newest material it holds, only for the newest among
  the hits a keyword query surfaced.
- **Accuracy — never cite a search hit unopened.** A search result may be selected on its title;
  it may not be *cited* on its title. The winner is opened through §Resolve and §Extract before it
  appears in an answer. This is the retrieve-don't-paraphrase rule (§Extract /
  §Answer) applied to the weakest class of candidate, where it matters most: a title is a claim about a document's contents, and
  repeating it as though it were the contents is the exact failure §Extract exists to prevent.

Guard three is what makes search safe to include in an answer at all. Without it the protocol trades
"no answer" for "a confidently wrong answer," which is a worse trade than the one it started with.

**The line the subagent must not cross.** A search agent returns locators and verdicts — never
citable document prose. If it read a document, summarized it, and the main agent answered from that
summary, the protocol would have rebuilt the paraphrase-a-cached-summary failure §Extract exists to
prevent, differing only in that the cache is fresher. What it may return is an assertion *about* a
document — is this on topic, what does it cover — which is metadata, not content. The main agent opens
what it cites.

## Why a subagent, and what it must be told

Search output is noisy in a way fetched content is not: dozens of hits, most irrelevant, each
carrying a path, an ID, a size, a date, an author. The judgment work in the section above consumes
all of it and produces a handful of rows. Loading the noise into the session's context to produce
the rows costs the session its remaining budget and buys nothing — the discarded hits are never
referenced again.

This is a pattern Parliament already relies on elsewhere: the critic dispatch in
`protocol/custodian-workflow.md` §4.1 runs Skeptic, Archivist, and Cartographer as subagents
precisely so each one's noisy working context stays out of the parent session. Search has the same
profile — bounded inputs, high-volume intermediate data, small structured output — so it gets the
same treatment, and `protocol/external-search-agent.md` is written to the same contract shape for
consistency.

Two of the inputs that contract hands down are not obvious, and search fails quietly without them:

- **Domain vocabulary.** A question is phrased in the user's words; the document is titled in the
  store's. "How does the satellite talk to the ground" does not keyword-match
  `KP-SYS-1234 Space-to-Ground ICD`. Translating between the two is the agent's first task, and the
  material for it — `## Scope` headers and `covers` text — is already in the main agent's context from
  §Filter and §Match. Handing it down costs nothing and is the difference between a search that finds
  the document and one that reports the store is empty.
- **The path to the covering catalog** (not its contents). Without it the agent cannot tell a genuine
  discovery from a row that already exists, so promotion appends duplicates and search degrades the
  corpus it exists to improve. Handing down the path lets the agent grep the catalog itself: full
  dedup coverage, and the catalog's hundreds of lines stay out of the main context. This is why the
  agent's restrictions are asymmetric — it **reads** `knowledge/` to dedup, and never **writes** it.

**One consequence is load-bearing and easy to miss.** `AskUserQuestion` is available only in the main
agent context; subagents cannot prompt (`protocol/security-policy.md` Layer 0,
`protocol/sensitive-data-patterns.md`). So a search agent **cannot come back for scope**. Everything
it needs — effort budget, which store roots, whether tenant-wide is authorized — must be settled
before dispatch. This is why the user prompt is specified as a pre-dispatch step rather than as
something the agent does when it gets stuck, and why the agent's failure mode on an unusable scope is
to return empty with a reason rather than to widen its own search.

## Why the output shape is a catalog row

The search agent returns rows in catalog form — `Document | Location | doc_type | authority |
Last Modified`, with `covers` left empty until a read fills it — rather than prose or raw hits. One
shape serves both consumers:

- **The answer path** needs a ranked candidate set with locators. A catalog row is one.
- **The promotion path** needs a row to append to a `type: index` catalog. A catalog row is one,
  once §Extract has supplied its `covers`.

Had these been two shapes, promotion would require a translation step that could be skipped, and a
skipped promotion is the whole gap reopening. Making the answer path's natural output *already* be the
promotion artifact means the expensive work is done once, by whichever stage had the data in context:
the agent infers `doc_type`, `authority`, and dates from paths it had in front of it, and §Extract
fills the one field that requires the document itself.

## Why the verification read sits at medium effort

At the lowest effort tier the agent returns candidates and stops; the main agent opens the winner. From
medium effort upward it opens the hits that clear a relevance bar and returns a **topicality verdict**
for each — on-topic yes/no, plus content-derived `covers` — and no citable prose.

**Why a bar and not a count.** A top-N cap looks like cost control and is actually an arbitrary
truncation: it discards the sixth plausible document for no reason other than its position in a
ranking the agent has not yet verified. The number of documents worth opening is a property of the
store and the question, not a constant — a narrow question against a rooted store yields two
candidates, a broad one yields eight, and both answers are correct. Relevance is the honest budget,
and it is self-limiting in the direction that matters: a query returning dozens of plausible hits is a
query that was too broad, so the response is to narrow the query, not to open thirty documents or to
silently keep three.

This also removes a silent cap, which the protocol treats as a defect in its own right — a truncated
result set reads exactly like a complete one, so an agent that opened three of eight and said nothing
has reported "here is what the store has" when it means "here is a third of what the store has."

Opening every clearing hit is worth its fetches for two reasons. It stops the main agent spending its
context on a document that a title made look right and a first page proves wrong. And it produces the
`covers` text that promotion requires, from the agent that has the document open, which is what lets a
row land as authored-quality rather than guessed — for **every** document promoted, not just the winner.

The cost is that a verified winner is fetched twice — once by the agent, once by the main agent for
citation. That is deliberate: the alternative is the subagent passing content up for citation, which is
the line § Why judgment is the hard part forbids. Bandwidth is the cheaper thing to spend than
grounding. A read-time fetch cache reduces the second read to a validation check where one is
configured, which makes the double fetch a non-issue rather than a tradeoff.

## Why a newer revision is a discovery, not a duplicate

Dedup exists to stop search re-proposing rows the corpus already holds. Applied naively — "name and
location already in the catalog ⇒ drop it" — it would discard the single most valuable thing a search
can find, because **a catalog goes stale by revision more often than by omission.** The row names Rev
A; the store holds Rev C; the folder and the document name are the same. That hit is not a duplicate of
the catalogued document, it is its successor, and dropping it leaves the corpus pointing at a
superseded document while reporting that it is current — the failure §Search was added to fix, reached
by a different route.

So dedup has three outcomes rather than two, and the middle one carries `supersedes`. No new mechanism
is needed: `supersedes` already exists with settled semantics, including what to do with the
still-present older row (`protocol/document-quality.md` § supersedes). Search discovers the
supersession; Parliament applies the field's existing rules when it merges. Inventing a parallel
"updated version" convention would strand every row already using the field.

## Why promotion requires a read

Promotion is what converts search from a recurring cost into a one-time one, so making it optional
would remove the argument for having search at all. It is also the step that closes the loop the gap
opened: the corpus learns the document exists, and the next session routes to it without searching.

But a row earns its place only if its `covers` text is accurate, and accurate `covers` cannot be
inferred from a path. `covers` is defined as what a document is *about* — the topical content an agent
matches a question against (`protocol/document-quality.md` § covers) — and a filename is a claim about
that, not a statement of it. A row whose `covers` was guessed is the thin-entry failure Goal 2
describes: it either invites an answer that should have been a fetch, or forces a fetch a better
sentence would have avoided. Written into a catalog, it is worse than absent, because the next session
trusts it as authored corpus content with no way to tell it was a guess.

**So the rule is: a document is promoted if and only if it was opened.** This lands the two paths on
the same read rather than making promotion a separate obligation:

| Stage | Produces |
|---|---|
| Search returns metadata | candidates, ranked — inference is sufficient here |
| §Resolve / §Extract opens the winner | grounded answer **and** content-derived `covers` |
| Promotion writes the row | a row whose `covers` came from the document |

The cheapest possible moment to write accurate `covers` is while the document is open, which is a
moment the answer path already pays for. Nothing is spent twice.

**A read that disproves relevance still promotes.** The title matched, the document is off-topic. The
answer path drops it and falls to the next candidate or §On no match. The row is still written, with
`covers` describing what the document actually contains. The document exists, it is genuinely absent
from the catalog, the read is already paid for, and a correct row stops the next session
re-discovering and re-opening it for the same wrong reason. A negative result is corpus improvement:
the gap §Search found was real whether or not this question needed it.

**Unopened runners-up are not promoted.** They are reported to the user as candidates worth a look —
locator and modification date, explicitly unopened — and recorded per §On no match if they suggest a
coverage gap. What they do not do is enter the corpus on the strength of a filename.

No new mechanism is required for the write, and the write is **not** the session's to make. Loop B's
obligation table already carries the row — "New external reference (URL, Confluence page, Jira board,
document) → the nearest `reference-library.md`, or the `type: index` catalog covering that store →
Parliament" (`protocol/learning-loops.md`). Search is a new *way of discovering* such a reference, not
a new kind of reference, so it uses the existing path: the session writes a `[link]` contribution
carrying the finished row, and Parliament appends it on the fast path, where §3 step 4 already routes a
named document in a catalogued store to that store's catalog. `[link]` auto-merges, so the corpus
gains the row without a review cycle.

**Why the session does not write the catalog directly.** A catalog is a knowledge file, and
`knowledge/**` is closed to agents by three independent controls: Goal 4 ("autonomous agents use the
inbox path only"), `git add` scoped to `_inbox/*` and `sources/*`, and a push ruleset that blocks
direct pushes touching `knowledge/`. Deposit's `sources/index.md` gate is not a precedent — `sources/`
is a separate content surface, deliberately outside `knowledge/`, and its gate is exempted from the
same ruleset. A promotion rule that had the session write the catalog would be a rule the harness
refuses to execute, which is worse than a slow one: the gate would silently no-op and search would
revert to a per-session cost, the exact failure promotion exists to prevent. Two additions to the
existing path, then:

- **`discovered_via: search` provenance**, so Parliament's Cartographer can see the row came from a
  live search rather than a trawl. The `covers` text is content-derived either way; what the marker
  records is that no human has reviewed the document's placement in the corpus.
- **A completion gate on the contribution**, matching the Deposit workflow's treatment of
  `sources/index.md` in *shape* though not in write target: an opened document is not done until its
  `[link]` contribution is written and pushed. Same reasoning as Goal 9's "the artifact is not
  deposited until it is indexed."

## Why search is not re-entrant

A search can surface a `type: index` catalog, which §Recurse will grep, whose rows are locators. If
search could fire again from inside that traversal, a single question could walk a store
indefinitely. §Recurse already bounds traversal at one additional level; search inherits that bound
and adds a stricter one — **once per store per question**. A store that answered nothing on a
well-formed query will not answer more on a second one, and the bound is what makes the cost of
§Search predictable enough to enable by default.

## Why the classification guard is a scope default, not a prohibition

Search widens exposure in a way fetching an indexed row does not. A catalog row was written by a
human who saw the document; a tenant-wide query returns titles nobody has vetted, and titles from
above a Hive's ceiling are a disclosure even when the documents are never opened.

The guard is therefore a **default scope** rather than a ban: search runs inside the store roots the
catalog already declares in `sources[]` — territory the Hive is already authorized to index — and
goes tenant-wide only on explicit user direction. This is the cheaper, more precise, and safer
choice simultaneously, which is the signal that it is the right default: a rooted query returns
fewer irrelevant hits *and* cannot surface a directory the Hive was never pointed at.

Note the inherited debt. `BACKLOG.md` deferred fetch-disposition (`load` | `cite-only` |
`query-live`) because its driver was classification exposure. That question is now live: a
`query-live` disposition is precisely the per-entry statement that a catalog row is a cache to be
revalidated rather than an answer, which is what the augment path assumes globally. Search does not
resolve that debt, and should not be read as having resolved it.

## What search does not fix

The miss path repairs the corpus **one asked question at a time**. It cannot surface a document
nobody happens to ask about, and it never reports that a catalog is months stale — it only ever
reveals the specific row that was missing for the specific question.

Corpus-level staleness is a different mechanism with a different owner: an Audit check comparing a
`type: index` catalog's `last_updated` against its store's observed write activity, recommending a
re-trawl. Audit's Freshness Check covers `knowledge/` files and does not currently reach catalogs.
Shipping search without that check would leave the Hive able to patch individual misses while
remaining unable to notice that its whole view of a store has drifted — the read-side half of the
problem, which Goal 9 requires any new content surface to name.
