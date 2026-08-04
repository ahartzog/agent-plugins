---
layer: PROTOCOL
type: workflow-extension
workflow: {WORKFLOW_NAME}
description: "{ONE_LINE_SUMMARY — what it does, and which knowledge file holds the mechanics}"
last_updated: {YYYY-MM-DD}
codeowners: [{GHE_HANDLE}]
delegates_to: [knowledge/{DOMAIN}/{MECHANICS_FILE}.md]
---

# Workflow Extension — {WORKFLOW_DISPLAY_NAME}

Merged into the upstream dispatch table by Apiary operate mode (Step 4). This makes
{WORKFLOW_DISPLAY_NAME} a first-class, named workflow — invoke it directly instead of hoping
the agent finds the knowledge doc.

Authoring guide: `references/authoring-workflow-extensions.md`.

## Dispatch Table Addition

| Input Pattern | Workflow |
|---|---|
| `{LITERAL_TOKEN}`, "{SPOKEN_VARIANT}", "{QUESTION_SHAPED_FORM}" | **{WORKFLOW_DISPLAY_NAME}** (this extension) |

**Disambiguation from {UPSTREAM_WORKFLOW}.** {ONE_PARAGRAPH: what the upstream workflow owns
vs. what this one owns, and the phrase that decides between them. If you cannot write this
paragraph, the workflow is not distinct enough to need a dispatch row.}

---

## What This Workflow Does

The mechanics of *how* this runs — {DATA_SOURCES}, {QUERIES}, {OUTPUT_RECIPE} — live in
**`knowledge/{DOMAIN}/{MECHANICS_FILE}.md`**. This extension does **not** duplicate them.
Its one job is {THE_ROUTING_DECISION_IT_MAKES} before the work begins.

> **Why {THE_ROUTING_DECISION} first.** {WHAT_GOES_WRONG_IF_YOU_SKIP_IT — the specific wrong
> output a user gets when the agent jumps straight to mechanics.}

---

## Step 0: {PRECONDITION} (REQUIRED — before anything else)

Ask and wait for answers. Do not {START_THE_WORK} until answered.

1. **{QUESTION_1}?** ({WHAT_IT_DETERMINES})
2. **{QUESTION_2}?** ({WHAT_IT_DETERMINES})

> If the user already stated these up front ("{EXAMPLE_FULLY_SPECIFIED_INVOCATION}"), skip the
> questions and route directly — don't re-ask what you were told.

Then run `knowledge/{DOMAIN}/{MECHANICS_FILE}.md` in full.

<!-- OPTIONAL: delete this section if the workflow has only one shape.
     If it serves several audiences with genuinely different structure/sources/owners,
     declare profiles here. Fully specify the one you know; leave others as honest stubs
     plus a generic fallback that ASKS rather than inheriting the known profile's sources.

## Profiles

### Profile: {VARIANT} — FULLY SPECIFIED
- **Owner:** {NAME} (`{HANDLE}`)
- **Structure:** {OUTPUT_SHAPE}
- **Data sources:** {SOURCES}

### Profile: {OTHER_VARIANT} — STUB
- **Owner:** {NAME}
- **Status:** Not yet run. Use the generic fallback; do not guess the data sources — ask.

### Generic Fallback Profile
- Ask the author which sources are authoritative for their variant. Do not inherit the
  specified profile's source list wholesale.
- Inherit all content rules from the mechanics knowledge file.

## Growing a Stub Into a Real Profile

First time a stub runs: run the generic fallback, then capture what you learned about that
variant as a `[process]` inbox contribution proposing a full profile. Parliament folds it back in.
-->

---

## Governance

This is a PROTOCOL file. Changes go via CODEOWNERS PR, not the inbox. The routing behavior
lives here; the mechanics live in `knowledge/{DOMAIN}/{MECHANICS_FILE}.md` and are maintained
there — one source of truth for each, no duplication.
