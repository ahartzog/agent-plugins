# The Knowledge Graph — Why Links, and Why Not More of Them

Design rationale for `protocol/link-authoring.md`, Loop B § Connections, and the Link Graph Health
audit step. Read this when changing any of them. Not loaded during normal operation.

## The failure this fixes

A Second Brain is built as a tree: an agent definition routes questions to knowledge files. That tree
is deliberate and it works — the agent definition's routing table is entirely about descending it.

What the tree cannot express is that two knowledge files are about the same thing. A term defined in
one file and used in six others has one authoritative home and six mentions, and nothing in the
routing table can say so, because routing answers "which file for this question," not "which file owns
this term." Cross-*domain* is worse: an edge between two domains belongs to neither domain's routing
table, so it ends up in the hub `CLAUDE.md` — a file that does not reliably load when an agent is
invoked by slash command or skill wrapper (DESIGN-GOALS §3). The cross-domain graph gets stored in the
one file the domains cannot read.

**Measured instances.** Three domains, 37 knowledge files: 2 wikilinks, 0 markdown links, and 133
backtick filename mentions. Sixteen distinct entities appeared in all three domains — one in 29 of the
37 files — with no link between any of them. A second, unrelated instance measured the same shape at
household scale: six domains, 257 content files, 187 wikilinks concentrated in 31 files, 765 backtick
filename mentions, and four of the six domains at exactly zero links.

## The cause was an instruction, not neglect

That hub's `CLAUDE.md` carried a "Cross-Linking Convention" section, copied from
`assets/hub-template.md`, which said routing rules were the *primary* mechanism, that file-level
cross-references should be *lightweight*, that authors should write ``see `{file}.md` ``, and that
"a one-way pointer is better than none."

The knowledge base complied, 133 times. It was not underlinked by accident; it was underlinked as
instructed. Worth noting where the instruction lived: `assets/`, which DESIGN-GOALS §3 already names as
the trap — template content is copied per hub and freezes there. The section sat three paragraphs below
that same file's own explanation of why restated content goes stale.

The lesson generalizes past linking: **a wrong instruction in a template is worse than a missing one,
because every hub inherits it and none of them can tell.**

## What links are actually for (and what they are not)

The strongest objection to this whole area, and it must be answered honestly: **an agent does not click
links.** Once a file is loaded, `` `budget-targets.md` `` already hands the model an exact filename it
can open. An agent finds files through its own routing table and grep, not by scanning inline links. So clickability buys nothing for retrieval, and a link count is not a quality metric.

Three things do survive that objection:

1. **Direction and reason.** A backtick filename asserts *a file exists*. A link marked
   `defined-by` asserts *this is where the term is authoritative* — decision-relevant information the
   backtick does not carry, for a human or a model. That is why the grammar requires a relation sense
   and forbids bare pointers.
2. **Anchors are retrieval economics.** `#Heading` on a 500-line file is the difference between
   reading a section and reading the file. This is the one benefit that is straightforwardly
   measurable in tokens.
3. **Humans read these files.** In an Obsidian vault the graph is a navigation surface a person uses
   directly. Not the primary justification, but not nothing.

**What remains unmeasured:** whether links improve *agent answer quality* versus inert backtick
references. No benchmark has been run. The honest claim is that links improve authority direction,
anchor precision, and human navigation; anyone claiming a retrieval-accuracy win should run
representative questions both ways and measure correctness, source coverage, and read count first.

## Why this is not a sixth loop

The first draft proposed "Loop F: Connections → Edges." It was rejected in review, correctly.

The five loops are differentiated by **state transition**, not by unit of knowledge: Loop A changes
agent rules, Loop C changes the custodian checklist, Loop D enters dispute handling, Loop E changes the
agent definition. A connection loop would write to knowledge files — the same destination, trust gate,
and contribution mechanics as Loop B. And a missing pointer already routes to Loop B on the
same grounds, explicitly — it is not a special case.

A sixth loop would also have to propagate through every surface that hard-codes five: mode-operate,
SKILL.md's principles, the audit's loop-health step, the triage prompt format, the maturity model, and
a long rationale document. That ceremony buys nothing a Loop B sub-block does not.

What *did* survive from the draft is the substance: connections are a distinct unit of knowledge with
their own triggers, and they fire in sessions where no new fact was learned. Hence a named sub-block
inside Loop B rather than a peer to it.

## Why traversal is the trigger, and why it still always prompts

The generative idea: **the traversal that produced an answer is the edge.** Any multi-file answer has
already discovered a relationship and used it. Recording the path you took costs nothing, and — this is
the point — it cannot invent a relationship, because the relationship was load-bearing in an answer
you already gave.

Its limits are real, and they are why `[edge]` is always-prompt rather than auto-eligible:

- **Co-reading is not causation.** Two files can be open for unrelated sub-questions.
- **A traversal can be an artifact of bad routing.** If you opened the second file because the routing
  table misdirected you, the fix is a routing rule or a reference-library entry, not a link. Only a
  human reliably tells these apart.
- **Cold start and popularity bias.** Files that answer questions alone never accumulate edges;
  well-connected seams get reinforced. The graph that emerges reflects traffic, not structure.
- **Instrumentation is partial.** `--read-manifest` sees `Read`/`Edit`/`Write` only. Grep, Glob, Bash,
  subagent, and external-store reads are invisible.

Co-occurrence — "these two files both mention X" — is deliberately *not* a session trigger. One term in
29 files licenses up to 406 pairs, which is precisely the link soup this design claims to avoid. It
belongs in Audit, which has the whole corpus in view and a human present.

## Star, not clique

When a term appears in many files, the naive graph links the files to each other: O(n²) edges, and n
copies of the same authority claim, each of which can drift.

Name one owner and point every mention at it: O(n) edges, one authority claim. This is why the relation
vocabulary is three senses rather than ten, and why `defined-by` is the one that carries most of the
weight — the vocabulary and the topology are the same design decision.

It also explains why the audit's co-occurrence sweep reports "term, file count, has an owner?" rather
than proposing pairs. A term in ten files with no owner is a **consolidation** finding. Sometimes the
right answer is not a link at all.

## Why edges are never a health score

Two metrics were considered and one was rejected.

- **`inert_refs`** counts pointers an author intended and did not write. It only falls, it cannot be
  gamed upward, and zero is a real target.
- **`edges`** was rejected. A maturity level that rewarded edge count would create a direct incentive
  to add meaningless links and never remove stale ones. Worse, it would punish the healthiest possible
  outcome: consolidating duplicated content *removes* the edges that existed to reconcile the copies.

So `references/maturity-model.md` grades inert references, broken links, and graph orphans — never
volume. Cross-domain edge count is reported and explicitly not graded, because a domain with no
neighbours is a legitimate case and a check that demanded neighbours would manufacture them.

## When a link is the wrong fix

The most common misuse. If two files both claim authority over the same content, a link between them
does not resolve the ambiguity — it blesses it, and creates an obligation to update both forever. Route
it `[architecture]` and consolidate.

In the measured instance, roughly a fifth of an automatically generated 199-edge proposal was rejected
on exactly this ground: the proposed links spanned duplicated registries, stale claims and their own
rebuttals, and two files that disagreed outright about which service provided a capability. Linking
those would have made contradictions look reconciled.

**Fix ordering matters.** Before a bulk linking pass: valid frontmatter, one owner per concept,
contradictions resolved, fast-decay status split out of slow reference files. Links drawn over a corpus
with unresolved authority encode the confusion permanently, and they are harder to unpick than to add.
