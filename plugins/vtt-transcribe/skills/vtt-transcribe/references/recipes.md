# Output recipes

Pick the recipe that matches the request. Combine recipes when the user asks for more than one ("summary plus action items"). A format the user specifies overrides any recipe here.

Every recipe follows the rules in `SKILL.md`: timestamps on claims, transcript-only sourcing, verbatim quotes.

---

## Summary (default)

```markdown
# <Title inferred from filename, e.g. Q3_Planning_Call.vtt -> "Q3 Planning Call">

## Overview
3-5 sentences: what this recording is, its thesis or purpose, and its outcome.

## Source
- `<file.vtt>` - <duration>, speakers: <labels or "unlabeled">

## Key Points
- <point> `[HH:MM:SS]`

## Detailed Summary
### <Section title> [HH:MM:SS--HH:MM:SS]
<what was said in this section>
```

Section breaks go where the topic shifts, not at fixed intervals. Thoroughness over brevity in Detailed Summary; brevity in Overview.

---

## Meeting notes

```markdown
# <Meeting title> - <date if stated in transcript or filename>

**Attendees (from speaker labels):** <names>; also note anyone mentioned as present who has no label

**Transcript caveats:** <entity spellings normalized, numbers reinterpreted, likely misattributions - omit the line if none>

## Decisions
- <decision> - <who made it> `[HH:MM:SS]`

## Action Items
| Owner | Action | Due | Ref |
|-------|--------|-----|-----|
| <name or "unassigned"> | <action> | <stated date or "-"> | `[HH:MM:SS]` |

## Discussion
### <Topic> [HH:MM:SS--HH:MM:SS]
- <point>

## Open Questions
- <question raised and not resolved> `[HH:MM:SS]`
```

An action item needs a commitment in the transcript ("I'll...", "can you... / yes"). A suggestion nobody took is an open question, not an action item. Never invent an owner or due date.

---

## Action items only

The **Action Items** table from Meeting notes, followed by **Open Questions**. Nothing else.

---

## Critical analysis

Adapted from [jftuga/transcript-critic](https://github.com/jftuga/transcript-critic/blob/main/ANALYSIS_PROMPT.md). Use for talks, podcasts, lectures, and videos where the user wants the argument evaluated.

Analyze only the transcript's content; ignore prior knowledge of the speaker or their typical positions. Define domain terms from context. Keep the tone descriptive: evaluate the reasoning, not the person.

```markdown
# <Title>

## Overview
3-5 sentences on thesis and scope.

## Source
- <URL as [URL](URL), or local path as `file.vtt`>

## Key Terms and Concepts
- **Term** `[HH:MM:SS]`: definition from the speaker's usage (timestamp of first mention)

## Detailed Summary
### <Section> [HH:MM:SS--HH:MM:SS]

## References
(Only if the speaker cites texts, studies, scripture, or other works.)
- **<Work>** `[HH:MM:SS]`, `[HH:MM:SS]`: how the speaker used it (all mentions, not just the first)

## Evidentiary Notes
- **<Category>** `[HH:MM:SS--HH:MM:SS]`: the claim and its support

## Logical Fallacies
- **<Fallacy>** `[HH:MM:SS--HH:MM:SS]`: where it appears and why it weakens the argument
(or "No significant logical fallacies detected.")

## Questions and Underdeveloped Areas
- `[HH:MM:SS]`: what is ambiguous or unsupported; state when an interpretation is uncertain
```

**Evidence categories:** Anecdotal (personal experience) · Appeal to authority (someone's opinion, no direct source) · Logical argument (reasoning without external data) · Cited source (specific, verifiable study, article, or data point).

**Fallacies:** flag only ones that materially weaken the argument; rhetorical flourishes are not fallacies. Watch for ad hominem, straw man, false dichotomy, appeal to emotion, tu quoque, slippery slope, hasty generalization, false authority. Cite the span from premise to conclusion.

---

## Quotes

A list of verbatim quotes matching the user's criterion (most quotable, about topic X, by speaker Y).

```markdown
> "<verbatim text>"
> - <Speaker>, `[HH:MM:SS]`
```

Run the digest with `--window 0` so quote timestamps are cue-precise.

---

## Structured extraction

For "pull every X into a table / CSV / JSON". Run the digest with `--json`.

1. Confirm the schema. If the user gave fields, use them exactly. If not, propose fields in one line and proceed unless the request is ambiguous enough that the wrong schema wastes the work.
2. Every record carries a `timestamp` field (and `source` when there are multiple files), even if the user's schema omits it - say once that you added it.
3. Leave a field empty when the transcript doesn't state the value. Never fill it from inference without marking it (`"price": "~$40 (inferred)"`).
4. Write CSV/JSON to the requested path; show a 3-5 row preview in chat.

---

## Knowledge-base ingest

For "add this to my notes / vault / project doc".

1. Read the target file (or the vault's index/landing page) first. Learn its heading structure, link syntax (`[[wikilinks]]` vs markdown), frontmatter fields, and date format.
2. Extract only durable content: decisions, facts, commitments, definitions, numbers. Skip small talk and process chatter.
3. Place each item under the existing heading it belongs to; create a heading only when none fits.
4. Attribute each addition: `(source: <file.vtt> [HH:MM:SS])`.
5. If a transcript fact contradicts what the target file already says, don't overwrite it. List the conflict to the user with both versions and timestamps.
6. Report what was added, where, and any conflicts.

---

## Q&A

When the user asks a question about the recording rather than for a document: answer directly in chat, cite the timestamps that support the answer, and say plainly when the transcript doesn't contain the answer.
