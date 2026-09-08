# Golden Routing & Retrieval Cases

Golden cases for the Reference Library Discovery Protocol (`protocol/routing-protocol.md`) and its
companion schemas (`protocol/knowledge-schema.md`, `protocol/document-quality.md`,
`protocol/tool-tiers.md`). Each case pins a **RIGHT** and a **WRONG** behavior against a fixture in
this directory, and cites the protocol section that makes the call — so a future reader can tell
whether the test or the protocol is wrong when one of them changes.

These are prose specifications read and followed by an agent, not a compiled program. A case here
verifies that a subagent handed the protocol files and this fixture Hive behaves as the protocol
says it should — it cannot be asserted by a compiler, only judged against the acceptance criteria
below. `golden-routing.test.sh` runs the deterministic half (the fixtures are shaped correctly) on
every CI run and the LLM-judged half only when explicitly requested — see that file's header for
which is which.

## How to run a case

Hand a subagent the case's **Prompt** verbatim, with working directory set to
`skills/apiary/tests/golden/` (so `knowledge/reference-library.md` resolves as it would inside a
real Hive) and read access to the plugin's `protocol/` and `references/` directories. Compare the
transcript against **Pass** / **Fail**.

None of this fixture is real program content — see the no-program-names rule in the repo root
`CONTRIBUTING.md`. URLs are `example.sharepoint.com` / `example.quip.com` / `example.app.box.com`
placeholders; they do not resolve and are not meant to.

---

## Case 1 — One-hop local (baseline)

**Governing:** `routing-protocol.md` §Resolve (local file row of the Resolve table).

**Fixture:** `knowledge/reference-library.md` § Ground Segment, row "Ground segment architecture" →
`program/overview.md`.

**Question:** "What subsystems make up the ground segment?"

**Prompt:**
> You are answering a question using the Reference Library Discovery Protocol
> (`protocol/routing-protocol.md`). The Hive's knowledge tree is `knowledge/` in the current
> directory. Question: "What subsystems make up the ground segment?" Answer it, following the
> protocol, and show your work — which files you read and why.

**Pass:** Reads `knowledge/reference-library.md`, matches the "Ground segment architecture" row,
reads `program/overview.md` directly (a local file — no fetch), and answers citing that file
(mission planning console, T&C front end, RF link).

**Fail:** Attempts any external fetch. Answers without citing `program/overview.md`. Fabricates
subsystems not in the file.

---

## Case 2 — Two-hop with authority conflict (the regression case)

**Governing:** `routing-protocol.md` §Prefer ("Matched catalog rows" branch — rank by `authority`)
and §Recurse ("Apply §Prefer to that new candidate set first"). This is the scenario PR #657's
`Prefer`/`Recurse` ordering regression would have failed: `Prefer` reordered ahead of `Resolve`
with no `authority` metadata yet in context, and `Recurse` bypassing it entirely, meant *both*
catalog rows below would have been fetched, or the row order (not authority) would have decided
which one won.

**Fixture:** `knowledge/reference-library.md` § Ground Segment → `ground-segment/document-catalog.md`,
rows "Space-to-Ground Link Budget — Working Draft" (`authority: working`) and "PROJ-123
Space-to-Ground Link Budget Spec" (`authority: formal`) — same topic (link margin requirements),
same catalog, adjacent rows. **The working-draft row is listed first on purpose** — an agent that
picks by row order rather than the `authority` column fails this case even though it would have
"passed" a version of this fixture where the formal row happened to sort first. Do not reorder the
rows to make the case easier to eyeball; that would silently remove the coverage.

**Question:** "How is the space-to-ground link budget designed?" (a design question —
`routing-protocol.md` §Prefer's question-type table says design questions prefer `baseline` or
`formal`.)

**Prompt:**
> Using the Reference Library Discovery Protocol (`protocol/routing-protocol.md`), answer: "How is
> the space-to-ground link budget designed?" The Hive's knowledge tree is `knowledge/` in the
> current directory. Show which reference-library entry you matched, which catalog rows you found,
> and which row(s) you resolved — and why.

**Pass:** Matches the router row, greps the catalog, finds both rows, applies §Prefer's authority
ranking (`formal` > `working`) *before* resolving, and resolves/cites only the `formal` row (or
states clearly why it also needs the working draft, which would be wrong for a design question —
see Fail). Names `authority: formal` in the answer or reasoning.

**Fail:** Resolves (fetches/reads) both rows. Picks the working-draft row, or picks by row order
instead of `authority`. Cites the working draft without a caveat on a design question. Skips
grepping the catalog's `authority` column entirely.

---

## Case 3 — Store-relative folder row

**Governing:** `knowledge-schema.md` § Store Roots for `type: index` Catalogs ("Most store-relative
locations name a folder... resolve such a row as root + `Location` + `Document`") and
`routing-protocol.md` §Resolve (store-relative path row).

**Fixture:** `ground-segment/document-catalog.md`, row "Ground MTP Draft", `Location:
03 - Test/Working Docs/`, catalog frontmatter declares
`sources: [{url: "https://example.sharepoint.com/sites/demo/Shared%20Documents/", type: sharepoint}]`.

**Question:** "Where can I find the Ground MTP Draft, and what's its resolved URL?"

**Prompt:**
> Using the Reference Library Discovery Protocol, resolve the locator for the "Ground MTP Draft"
> row in `ground-segment/document-catalog.md`. State the fully resolved, fetchable URL — not just
> the row's `Location` cell.

**Pass:** Joins the declared store root + `Location` + `Document` name into one absolute URL:
`https://example.sharepoint.com/sites/demo/Shared%20Documents/03%20-%20Test/Working%20Docs/Ground%20MTP%20Draft`
(exact percent-encoding is not the point — the join is). States this is a SharePoint document it
would fetch with the `sharepoint` skill.

**Fail:** Reports the bare `03 - Test/Working Docs/` cell as the answer. Claims the row is
unresolvable (the root *is* declared here, unlike Case 4). Fetches without stating the resolved
URL.

---

## Case 4 — Missing store root

**Governing:** `routing-protocol.md` §Resolve ("A store-relative row whose file declares no store
root is unresolvable: treat it as a broken pointer"), `knowledge-schema.md` § Store Roots (the
must-declare requirement: a catalog with store-relative rows "**must** declare the store root in
frontmatter `sources[]`"), and `routing-protocol.md` §On no match ("a locator that would not
resolve... Tag it `[link]`").

**Fixture:** `knowledge/reference-library.md` § Ground Segment, row "Legacy ground interface
catalog" → `ground-segment/broken-catalog.md`, row "Legacy Command Format Register",
`Location: Archive/Legacy Interfaces/`. This catalog's frontmatter has **no** `sources[]` at all.

**Question:** "What's the pre-2025 command format, per the legacy ground interface catalog?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What's the pre-2025 command format, per
> the legacy ground interface catalog?" If you cannot fully answer, say what you did instead and
> whether you recorded anything.

**Pass:** Matches the row by `covers` text, then recognizes `ground-segment/broken-catalog.md` has
no `sources[]` and the row is a store-relative folder path with nothing to resolve against. States
the document is unreachable (broken pointer), does not claim to have read it, and states it would
record (or does record) a `[link]` inbox contribution naming the unresolvable locator per §On no
match.

**Fail:** Answers as though the document's contents were known (reporting the row's `covers` text —
"pre-2025 command format" — as if it were the format itself). Silently drops the question. Claims
the row resolves.

---

## Case 5 — ID-addressed store

**Governing:** `routing-protocol.md` §Resolve (the absolute-URL row of the locator-kind table) and
`external-retrieval-design.md` § Why absolute URLs are preferred ("For those stores 'relative path'
is not a concept and a store root buys nothing").

**Fixture:** `knowledge/reference-library.md` § Program Documents, row "Program decision log
(Quip)" → `program/id-store-catalog.md`, row "IPT Decision Log — May 2026",
`Location: https://example.quip.com/NieRAn8pvonB`.

**Question:** "What did the IPT decide about CDR follow-ups?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What did the IPT decide about CDR
> follow-ups?" State which tool you'd use to open the resolved locator and why.

**Pass:** Recognizes the row's `Location` is already an absolute URL (`quip.com` host), dispatches
straight to the `quip-mcp` tool per `tool-tiers.md` § Store Kind → Tool, and does not attempt to
join it to any root (there is none declared, and none is needed — the catalog's `sources[]` entry
names only `type: quip`).

**Fail:** Tries to treat `NieRAn8pvonB` as a relative path and join it to some root. Asks for a
store root that doesn't exist. Reports the catalog's `sources[]` (no `url`) as a missing-root
defect — it is not; ID-addressed catalogs need no root (see Case 4 for what an actual missing-root
defect looks like).

---

## Case 6 — `covers` absent (filename-only match)

**Governing:** `document-quality.md` § covers ("a row whose only free text is a filename can be
matched only by filename") and `routing-protocol.md` §Extract ("matching is by filename only — say
so rather than reporting a filename match as a topical one").

**Fixture:** `ground-segment/document-catalog.md`, row `2.1_2.4 - CDR Ground Segment Design
(Internal).pptx`, empty `covers` cell.

**Question:** "How does flight dynamics hand off to T&C?" (the document-quality.md worked example —
the filename shares "Ground Segment Design" and "CDR" context but does not mention flight dynamics,
handoff, or T&C by name.)

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "How does flight dynamics hand off to
> T&C?" Search the ground segment document catalog. Be explicit about whether any row is a
> confirmed topical match or only a filename-level guess.

**Pass:** Either (a) finds no confident match and says so — this catalog's row for CDR ground
segment design has no `covers` text, so it can only be matched by filename, and the filename alone
does not confirm the topic — and offers to fetch it to check, or (b) fetches the row explicitly
*because* the pointer wasn't enough, and only then answers from the fetched content. Either way, it
states plainly that the row carries no `covers` text and any match is filename-level, not topical.

**Fail:** Reports the CDR row as a confirmed topical hit for "flight dynamics hand off to T&C"
without opening it. Silently invents an answer. Does not mention the missing `covers` column at
all.

---

## Case 7 — `covers` sufficient — no fetch (Goal 2 economy)

**Governing:** `document-quality.md` § covers ("A row with real coverage terms can *be* the answer
for a scoping question... which avoids a fetch entirely") and `routing-protocol.md` §Extract
("A row's `covers` text can fully answer a scoping question").

**Fixture:** `ground-segment/document-catalog.md`, row "PROJ-123 Ground Station RF Interface
Requirements", `covers: ground station RF link requirements, EIRP thresholds, G/T requirements`.
This row is deliberately distinct from Case 2's link-budget pair — a scoping question here should
not entangle with the authority tiebreak Case 2 tests; each case isolates one behavior.

**Question:** "Which document defines the ground station's EIRP requirements?" (a scoping question —
asks *which document*, not what the values are.)

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "Which document defines the ground
> station's EIRP requirements?" State whether you fetched anything, and why or why not.

**Pass:** Answers "PROJ-123 Ground Station RF Interface Requirements" directly from the catalog
row's `covers` text, cites the row, and explicitly states it spent no fetch — the question is a
scoping question the `covers` text already answers.

**Fail:** Fetches the SharePoint document anyway before answering. Cannot name the document without
fetching (i.e. fails to use `covers` as a matchable field at all).

---

## Case 8 — Tool missing → explicit degradation

**Governing:** `tool-tiers.md` § Degradation Patterns, `workflows.md` § Cross-Cutting Discipline →
"Missing skill transparency," and `routing-protocol.md` §On no match ("Record the same way when
routing reached an entry but the material stayed out of reach... a store whose tool is not
installed").

**Fixture:** `knowledge/reference-library.md` § Program Documents, row "Vendor deliverable catalog
(Box)" → `program/vendor-deliverable-catalog.md`, row "Demo Corp CDR Chart Package",
`Location: https://example.app.box.com/file/998877665544`.

**Question:** "What did Demo Corp's CDR chart package say about review board comments?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What did Demo Corp's CDR chart package
> say about review board comments?" **For this exercise, treat `box-skill` as NOT installed in
> your current session, regardless of whether it actually is** — this case is testing the
> degradation path, not real Box access.

**Pass:** Names `box-skill` as the tool needed, states it is not installed for this exercise, gives
the resolved URL (`https://example.app.box.com/file/998877665544`) so the user could open it
directly, offers the install path, does **not** answer the question from the row's `covers` text as
though the document had been read (the row only says the deliverable covers "review board comments"
generically — it does not say what those comments *were*), and states that this unreachable-tool
case should be (or was) recorded as a `[link]` gap per §On no match — an agent working in a real
Hive would write and push this without asking; in this synthetic fixture tree (no `_inbox/`),
stating the intended contribution in the answer satisfies the criterion.

**Fail:** Answers the question using only the catalog row's `covers`/metadata text, presenting it as
though the chart package had been opened. Silently gives up with no URL or install offer. Never
names `box-skill` by name. Treats the unreachable pointer as merely a degraded answer rather than a
routing defect worth recording.

---

## Case 9 — Mixed-store catalog, one root declared (optional extra)

**Governing:** `knowledge-schema.md` § Store Roots ("More than one store in one catalog is
allowed — declare one `sources[]` entry per store") and `mode-audit.md` Step 1c check 6 ("One root
per store").

**Fixture:** `program/mixed-store-catalog.md` — frontmatter declares only a `sharepoint` root; rows
are "Ground SDD Rev B" (SharePoint, resolvable) and "orbital-planner README" (GHE, `Location:
github.com/example-org/orbital-planner`, no GHE root declared anywhere in the file).

**Question:** "Where's the design documentation for the mission-planning contact-window scheduler?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "Where's the design documentation for
> the mission-planning contact-window scheduler?" This catalog spans two different stores — be
> explicit about which rows resolve and which don't, and why.

**Pass:** Matches the "orbital-planner README" row by `covers` text, recognizes its `Location` is a
GHE path (not the declared SharePoint root — the declared root only covers the *other* row), and
states this row is unresolvable for lack of a declared GHE root, distinct from the SharePoint row
which resolves fine. Does not apply the SharePoint root to the GHE row.

**Fail:** Joins the GHE row to the declared SharePoint root (produces a nonsense URL). Reports the
whole catalog as either fully resolvable or fully broken — it is neither; the two rows differ.

---

## Case 10 — Directory-pointer Source (optional extra)

**Governing:** `knowledge-schema.md` § Reference Library Entry Format ("Directory pointers... A
Source cell may name a directory with a trailing slash... covers every `.md` file in that
directory") and `mode-audit.md` Step 1b ("Also extract directory pointers... Verify the directory
exists and contains at least one `.md`; flag an empty or missing directory as a broken pointer").

**Fixture:** `knowledge/reference-library.md` § People, row "Team profiles" → `people/profiles/`
(trailing slash, no filename) — covers `people/profiles/jane-demo.md` and
`people/profiles/sam-demo.md`.

**Question:** "Who's the point of contact for the RF link?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "Who's the point of contact for the RF
> link?" The Source cell for this entry names a directory, not a file — explain how you resolved
> that.

**Pass:** Recognizes the trailing-slash `people/profiles/` cell as a directory pointer covering
every `.md` beneath it (not a broken or missing-file pointer), reads the files in that directory,
and answers "Sam Demo" (his profile names the RF link) citing `people/profiles/sam-demo.md`.

**Fail:** Reports `people/profiles/` as an unresolvable or missing-file locator. Reads only one
profile and guesses instead of checking both. Cannot distinguish this from Case 4's genuinely
broken pointer — the difference is that a directory pointer resolves by definition once the
directory exists and is non-empty, whereas Case 4's row is unresolvable because no store root was
declared for a *store-relative* (not local-directory) location.

---

## Case 11 — Indexing: absolute URL, internal, numbered document

**Governing:** `document-quality.md` § doc_type, § authority, § covers, § Trawling Heuristics (gate
1: "Has a document number... → `authority: formal`").

**Task, given to the subagent verbatim (not read from a fixture file — this is the indexing
direction, producing a row rather than resolving one):**

> A document exists with these facts: title "KP-ICD-0417 Space-to-Ground Command & Telemetry ICD
> Rev C"; it is a signed, configuration-managed interface document with an assigned document
> number; it defines uplink/downlink framing, command formats, and link margin allocations; it is
> internal to the program (no external vendor); it lives at
> `https://example.sharepoint.com/sites/demo/Shared%20Documents/06%20-%20Ground%20Segment/ICDs/KP-ICD-0417_RevC.docx`;
> last modified 2026-03-01.
>
> Produce a catalog row for it per `protocol/document-quality.md`, in the column order:
> `Document | Location | covers | doc_type | authority | source_org`.

**Pass:**
- `covers` names subjects ("uplink/downlink framing, command formats, link margin allocations" or
  equivalent) — not a restatement of `doc_type` or role ("ICD document", "interface document").
- `authority` is exactly `formal` (document number present — Trawling gate 1 fires; do not use
  `baseline` or invent a compound value).
- `doc_type` is `icd` (or `cdrl`, since it carries a document number in the `KP-` series — either
  is defensible; flag as **Fail** only if it is neither).
- `Location` is the given absolute URL, verbatim or lightly normalized — not rewritten as a
  store-relative path when an absolute one was already supplied.
- `source_org` is empty/omitted — the document is internal.

**Fail:** `covers` restates the document's class or role instead of its subjects. `authority`
holds an organization name, a person name, or a compound value. `authority` is `working` or
`baseline` despite the stated document number. The absolute URL is discarded in favor of a
constructed relative path.

---

## Case 12 — Indexing: store-relative, vendor deliverable with a document number

**Governing:** `document-quality.md` § source_org, § Trawling Heuristics (gate ordering — "stop at
first match": gate 1 fires before gate 4 even when the document is *also* vendor-delivered),
`routing-protocol.md` §Resolve ("A store-relative row whose file declares no store root is
unresolvable"), and `knowledge-schema.md` § Store Roots (a catalog with store-relative rows
"**must** declare the store root in frontmatter `sources[]`").

**Task, given to the subagent verbatim:**

> A document exists with these facts: title "KP-SYS-0099 Ground-to-Space ICD Rev C"; it carries an
> assigned, configuration-managed document number; it was formally delivered by an external vendor,
> "Acme Systems", under tracked delivery; it defines the ground-to-space interface, message
> formats, and timing; it lives in a Box folder at
> `https://example.app.box.com/folder/55667788` under the filename `KP-SYS-0099_RevC.pdf`; last
> modified 2026-02-20.
>
> Produce a catalog row for it per `protocol/document-quality.md`, in the column order:
> `Document | Location | covers | doc_type | authority | source_org`. Also state whether the
> catalog this row lives in needs a declared store root, and why.

**Pass:**
- `authority` is `formal` — the document number (gate 1) takes priority over the vendor-delivery
  signal (gate 4) per the trawling heuristics' stop-at-first-match ordering. (A response that
  argues for `delivered` with an explicit, correct citation of why it weighed vendor origin over
  the document number is **Fail** — the gates are priority-ordered, not a judgment call.)
- `doc_type` is `cdrl` (has a document number in the `KP-` series).
- `source_org` names "Acme Systems" — vendor attribution lives here, never folded into `authority`.
- `covers` names subjects ("ground-to-space interface, message formats, timing") not role/class.
- Declares (or states it should declare) a Box store root for the catalog, since the Location
  given here is a folder + separate filename, not a full absolute file URL — an absolute URL to
  the file itself is also acceptable if the agent constructs `https://example.app.box.com/folder/
  55667788/KP-SYS-0099_RevC.pdf`-style locator and says so explicitly.

**Fail:** `authority` is `delivered` (skips gate 1). `Acme Systems` appears in the `authority`
column instead of `source_org`. `covers` says "vendor deliverable" or "ICD" instead of the actual
subjects. No mention of store-root resolvability for a folder-style location.

---

## Case 13 — Recency-shaped question: sufficiency verdict stated, search bounded honestly

**Governing:** `routing-protocol.md` §Prefer ("run §Search's sufficiency test before resolving
anything, and state the verdict in one line"), §Search's sufficiency test ("a catalog row's date is
the document's date *as of the trawl*, so it structurally cannot say what is newest now"), and
§Search ("Ask the user before dispatching").

**Fixture:** `ground-segment/document-catalog.md` — frontmatter `last_updated: 2026-06-01`, rows
carrying `Last Modified` dates from the trawl, SharePoint store root declared in `sources[]`.

**Question:** "What's the latest link budget document — did anything land after the last catalog
update?" (recency-shaped by construction: "latest", "did anything land".)

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What's the latest link budget document —
> did anything land after the last catalog update?" You have no store-search tool installed in this
> exercise. Show the sufficiency verdict the protocol requires, and what you do about it.

**Pass:** Matches the link-budget rows, then **states the sufficiency verdict explicitly** (e.g.
`sufficiency: insufficient — recency-shaped`), explaining that catalog dates are trawl-time dates
and cannot establish what is newest now. Because no search tool is available, it does NOT fabricate
a search: it answers from the newest catalogued row *labeled as the newest known to the catalog as
of the trawl*, names the missing capability (per `tool-tiers.md` § Degradation Patterns — the
`sharepoint` search primitive), and states it would record the gap per §On no match. Bonus: lays
out the candidate rows with their dates and names the max mechanically before choosing.

**Fail:** Answers "the latest is X" with no trawl-date caveat, presenting a catalog row as current
truth for a recency question. Never states a sufficiency verdict. Claims to have searched the live
store. Treats the frontmatter `last_updated` as the documents' modification date.

---

## Case 14 — Abstention: in-domain question with no coverage → flagged ungrounded + gap recorded

**Governing:** `routing-protocol.md` §On no match ("Answer from general knowledge, **explicitly
flagged as ungrounded** — say the Hive has no knowledge file covering this" + "Write an inbox
contribution capturing the coverage gap") and §Search's hard non-trigger ("if no `## Scope` matched
any domain, do NOT search" — here scope DOES match, but no search tool exists in this exercise).

**Fixture:** the whole fixture tree — its reference-library `## Scope` covers the ground segment,
but no entry, catalog row, or knowledge file mentions thermal vacuum testing.

**Question:** "What's the thermal vacuum test schedule for the ground segment radios?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What's the thermal vacuum test schedule
> for the ground segment radios?" You have no store-search tool installed in this exercise. If you
> cannot fully answer, say exactly what you did instead and what you recorded.

**Pass:** Finds no matching entry or row, states plainly that the Hive has no knowledge covering
thermal vacuum testing, gives any general-knowledge answer **explicitly flagged as ungrounded**
(or declines), and states it would record (or does record) a `[process]` coverage-gap inbox
contribution per §On no match — in this synthetic fixture tree (no `_inbox/`), stating the intended
contribution satisfies the criterion. Does not invent a schedule, a document, or a search.

**Fail:** Fabricates a schedule or cites a document the fixture does not contain. Answers from
general knowledge without the ungrounded flag. Silently gives up without recording (or naming) the
gap. Reports the `covers` text of an unrelated row as if it covered thermal vacuum testing.

---

## Case 15 — `sources/` read path: exact-value question falls through to the verbatim original

**Governing:** `routing-protocol.md` §Resolve (the **Hive-root path** locator row — `sources/…`
resolves from the Hive root, not `knowledge/`) and §Extract ("Fall through to the verbatim original
when the wording *is* the answer").

**Fixture:** `sources/index.md` (manifest) → `sources/meeting-transcripts/2026-07-15-jrivera-link-budget-sync.md`
(verbatim transcript, states **4.7 dB**), plus `knowledge/ground-segment/link-budget-notes.md` — a
curated paraphrase of the same session that rounds the figure to "roughly 5 dB" and names the
transcript in its `sources[]` frontmatter. The reference-library carries the row
`sources/index.md`, written exactly as `protocol/sources-policy.md` § Reference-Library Pointer
prescribes.

**Why this case exists:** the prescribed router row is `sources/index.md`. Under the pre-2.24.0
§Resolve rule — "Local file … relative to `knowledge/`" — that token resolved to
`knowledge/sources/index.md`, which does not exist in any Hive. The Hive's highest-fidelity
material was addressable and unreachable, and Audit Step 1b independently reported the same row as
a broken pointer. This case pins the fix on both sides.

**Question:** "What exactly did the team commit to for downlink link margin — quote the number
from the session."

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "What exactly did the team commit to for
> downlink link margin — quote the number from the session." The knowledge tree is ./knowledge here.
> State which file you quoted from.

**The prompt must NOT name `./sources`.** Telling the agent where deposited sources live pre-resolves
the exact locator the §Resolve Hive-root row exists to resolve — the case would then pass with that
row deleted, which is the one thing it is here to detect. The agent has to reach `sources/` the way
a real session does: match the router row, then resolve `sources/index.md` from the Hive root.

**Pass:** Resolves `sources/index.md` from the **Hive root** (not `knowledge/sources/index.md`),
reaches the transcript, and answers **4.7 dB**, citing the transcript path. Recognizing that the
paraphrase in `link-budget-notes.md` rounds the value, and saying so, is a stronger pass.

**Fail:** Answers "roughly 5 dB" from `link-budget-notes.md` and presents it as the committed
figure — the precision-loss failure this clause exists to prevent. Reports `sources/index.md` as a
broken or missing pointer. Resolves the row against `knowledge/` and declares the sources
unreachable. Quotes "4.7 dB" without having opened the transcript (an unopened citation — §Answer
forbids it, and the trace makes it detectable).

---

## Case 16 — Routing trace: every citation names an opened locator

**Governing:** `routing-protocol.md` §Answer ("Close with the routing trace — one line", "Every
citation in the answer must name a locator that appears in `opened:`", "An empty `opened:` means
§On no match must have fired") and §Match ("Record the restatement in §Answer's trace").

**Fixture:** the whole fixture tree; any answerable question exercises it. Case 1's one-hop local
question is used so the trace is asserted independently of retrieval difficulty.

**Question:** "How is the ground segment structured — what are its subsystems?"

**Prompt:**
> Using the Reference Library Discovery Protocol, answer: "How is the ground segment structured —
> what are its subsystems?" The knowledge tree is ./knowledge here. End your answer with the
> routing trace the protocol requires.

**Pass:** Answer ends with a single-line `trace:` carrying the restatement, the library/match
counts, and an `opened:` list; `program/overview.md` appears in `opened:` and is the file cited in
the answer body. Every citation in the body resolves to something in `opened:`.

This route is one-hop and local — it reaches no catalog rows, so §Prefer's sufficiency test is
never asked and the trace correctly carries **no** `sufficiency:` field. Emitting one here is a
fabricated verdict, not a completeness bonus (§Answer, "Omit a field the route never produced").
Case 13 is where the sufficiency verdict genuinely binds.

**Fail:** No trace line. A trace whose `opened:` list omits a file the answer cites — that is the
unopened-citation defect the rule exists to catch, and it is a **harder** fail than omitting the
trace entirely, because the answer looks sourced. A trace expanded into a multi-paragraph narration
of each step (the cost this was deliberately bounded to one line to avoid).
