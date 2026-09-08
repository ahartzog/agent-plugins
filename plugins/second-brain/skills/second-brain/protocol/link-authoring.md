---
type: protocol
description: "Link grammar for knowledge-file cross-references — the three relation senses, anchor durability, path qualification, and placement. Demand-loaded: read it when about to write a link."
last_updated: 2026-09-08
---

# Link Authoring

**Demand-loaded.** Operate mode does not read this file. Read it when you are about to write a
cross-reference between knowledge files — `protocol/learning-loops.md` Loop B § Connections points
here. Protocol, consulted on use, not held in every session.

Rationale, failure modes, and the argument for why this is not cosmetic: `references/link-graph.md`.

---

## A filename in backticks is not a link

`` `budget-targets.md` `` and "see budget-targets.md" are **inert references**: written with the intent
of a pointer, inert in practice. They carry a filename and nothing else — not the direction, not the
reason, not the section. They are a defect class, and the cheapest one to measure (Audit counts them,
and `scripts/link_inert_refs.py` converts the unambiguous ones).

Write the link instead. This is the single most common repair in an existing knowledge base, and
converting an inert reference is strictly better than adding a new link elsewhere: the author already
decided the pointer belonged there.

---

## Grammar

Two grammars, because the same path means different things in each. Detect the environment the way
SKILL.md § Environment Detection does — `.obsidian/` present or not.

| Mode | Form | Path is resolved against |
|---|---|---|
| Plain markdown | `[display](relative/path.md#heading)` | the **source file's** directory |
| Obsidian | `[[Domain/file#Heading\|display]]` | the **vault root** (path-qualified prefix) |

Plain markdown is the floor — implement it first, always (DESIGN-GOALS §5). Obsidian wikilinks are the
enhancement, and they are *not* the same address: a plain-markdown sibling link is `./insurance.md`
while the Obsidian form is `[[Financial/insurance]]`. Do not mechanically translate one into the other
by adding or stripping `.md`.

### Always path-qualify

A bare `[[overview]]` resolves by basename, silently, to whichever file the editor picks. Basenames
collide hard in real vaults. A live household vault of 257 content files carries 9 files named
`index.md`, 8 named `skill.md`, 7 named `CLAUDE.md`, 4 named `overview.md`, and 2 named `vehicles.md` —
and that last pair is the whole problem in miniature, because `Household/vehicles.md` and
`Financial/vehicles.md` genuinely reference each other. `[[vehicles]]` written in either one is a coin
flip that never reports an error.

Path-qualify at **write** time. Audit's ambiguity check (`references/mode-audit.md` § Wiki-Link
Integrity) is a backstop for links that already exist, not a substitute for writing them correctly.

### Keep the path greppable

The path must remain visible inside the link. A display alias is good for readability and encouraged —
but grep over the knowledge files is how an agent actually finds things, so an alias that *replaces*
the path removes the file from every future search.

```
GOOD  [[Financial/Taxes/tax-overview#Capital Improvements|the capital-improvement basis rules]]
BAD   [[the capital-improvement basis rules]]
```

### Two escaping cases that silently break links

- **Inside a table cell, escape the alias pipe:** `[[path\|display]]`. An unescaped `|` is read as a
  column separator and shears the link in half.
- **When an anchor ends in `]`** — headings here often carry `[learned: …]` / `[superseded: …]` /
  `[decided: …]` suffixes — add an alias so the anchor terminates at the `|` rather than colliding with
  the closing `]]`: `[[Household/property#Maker & Computing Hardware [learned: 2026-08-16]|the Pi 4]]`.

A link inside a fenced code block does not render at all. Put it in the adjacent prose.

### Renames and moves break links in three different ways

A link is a *reference*, so anything that changes a target's identity can invalidate it. The three
cases behave differently, and only one of them self-heals:

| What changed | Inbound links | Why |
|---|---|---|
| File renamed/moved **inside Obsidian** | Rewritten automatically, *if* "Automatically update internal links" is on | The editor owns the operation and knows every backlink |
| File renamed/moved **outside Obsidian** — git, an agent, `mv`, a sync client | **Not touched.** Every inbound link dangles | Nothing observed the rename |
| A **heading** renamed, anywhere | **Not touched.** Every `#Heading` anchor dangles silently | No editor tracks heading identity |

Consequences for how you work:

- **Agents move files outside Obsidian.** That is the normal case for this skill, so treat any file
  move as a link-breaking change: grep for inbound references to the old path and fix them in the same
  change. Audit's broken-link check (`references/mode-audit.md` § Link Graph Health) is the backstop,
  not the plan.
- **Renaming a heading is the quietest of the three** — a dangling anchor still looks like a working
  link. Grep for `#<old heading>` before renaming, always.
- **Set the vault's link format to absolute, or Obsidian's own auto-update will erode the convention.**
  When Obsidian rewrites links after a rename it regenerates them using the "New link format" setting
  rather than preserving each link's existing style. On the default "Shortest path when possible" it
  strips the folder path from any link whose basename is currently unambiguous — converting
  `[[Domain/file]]` into `[[file]]`, which is precisely the bare form this protocol forbids, and which
  becomes a silently-wrong link the day a second file with that basename appears. Set
  **Settings → Files and links → New link format → Absolute path in vault** so rewrites keep the path.
  (Obsidian behavior, verified against the setting's documented purpose and widely reported; not
  confirmed in an official doc page stating it in these terms.)

---

## Three relation senses

A link the reader can't predict is a link they won't follow. Say **why** to go there. Use plain
prose carrying one of three senses — there is no tag syntax to learn, and deliberately no more than
three:

| Sense | Means | Prose that carries it |
|---|---|---|
| `defined-by` | the target owns this term; go there for the authoritative statement | "authoritative definition in X", "X owns this", "eligibility rules live in X" |
| `depends-on` | this consumes, is downstream of, or is constrained by the target | "depends on X", "consumes X", "the spend side of this is X" |
| `superseded-by` | the target replaced this | "superseded by X" — pairs with the `[superseded:]` annotation |

Three, not ten, because a vocabulary an author cannot classify confidently collapses to whichever
value feels safest, and then the type carries no information at all. Extend only when a real
classification failure demands it — same discipline as `doc_type_extensions` in
`references/document-quality.md`. Record the extension and why.

**`defined-by` is the one that scales.** When a term appears in many files, do **not** link the files
to each other — that is O(n²) edges and n copies of the authority claim. Name one owner and point
every mention at it. The shape is a star, not a clique. FSA balances are the worked case: Medical owns
eligibility, Financial owns the balance, and every other mention points at one of those two rather
than at each other.

---

## Anchors decay; choose the level deliberately

| Target's `decay` | Link at |
|---|---|
| `slow`, `medium` | a `#Heading` — the anchor is worth the precision, and saves reading the file whole |
| `fast` | the **file**, never a heading |

Status headings churn. A `#Heading` into a fast-decay file breaks quietly and is worse than no anchor
at all, because a broken anchor reads as a working link.

- **Copy headings verbatim, including unicode.** These files use em-dashes (`—`, U+2014), not hyphens,
  and often carry `[learned: …]` / `[decided: …]` suffixes. A hyphen typed where an em-dash belongs is
  the most common broken anchor there is.
- **Renaming a heading is a link-breaking change.** Grep for inbound anchors before renaming.

---

## Placement

Put the link **at the mention**, inline, where a reader is already confused. That is the whole value:
a pointer arriving at the point of need.

A bottom-of-file `## Related` list is a *second tree* — file → its list — not an edge attached to a
fact. Use it only for a whole-file relationship with no natural anchor, and keep it short.

**Link a term once per section, not once per occurrence.** Repeating the same target three times in
one section is noise; the reader followed it the first time or chose not to.

### `## Adjacent Domains` — the cross-domain seams

A domain index may carry an `## Adjacent Domains` table naming the domains it borders. This is
**opt-in**, not required — nothing about it should block an L1 setup (DESIGN-GOALS §4). It earns its
place where cross-domain routing exists only in a hub `CLAUDE.md`, because a hub file does not
reliably load when an agent is invoked by slash command or skill wrapper (DESIGN-GOALS §3) — i.e. the
cross-domain graph ends up stored in the one file the domains cannot read.

```markdown
## Adjacent Domains

| Domain | Seam | Route |
|---|---|---|
| Financial | capital improvements raise cost basis → tax treatment | [[Financial/index]] · `/sterling` |
```

The Seam cell names the boundary. "Related work" is not a seam.

---

## Ownership: linking into a domain you don't own

Adding an outbound link from your own file is a write. Adding an inbound link *into another domain's*
file is a **proposal** — surface it, don't apply it. Raw-data folders are immutable by rule, some
domains are additive-edit-only, and a second maintainer did not agree to your graph.

---

## Edges are not permanent

An edge whose target no longer covers the subject is a defect, not history. When consolidating
duplicated content, **delete the edges that existed only to reconcile the duplication** — that
reduction is the success condition, not a regression. Growth in edge count is not evidence of health,
which is why nothing in `references/maturity-model.md` grades it.
