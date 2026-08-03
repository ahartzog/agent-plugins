---
domain: ground-segment
type: reference
description: "Curated notes from the 2026-07-15 link budget working session — paraphrase; the deposited transcript is the verbatim record."
decay: medium
confidence: medium
last_updated: 2026-07-16
sources:
  - path: "sources/meeting-transcripts/2026-07-15-jrivera-link-budget-sync.md"
    type: meeting-transcripts
---

# Link Budget Working Session — Notes

Curated summary of the 2026-07-15 session. **This is a paraphrase.** The verbatim record is the
deposited transcript named in `sources[]` above.

## What was settled

- The team agreed on roughly 5 dB of downlink link margin at the low-elevation mask, after folding
  in pointing loss. [effective: 2026-07-15] [learned: 2026-07-16]
- Sustained primary downlink data rate is 150 Mbps — unchanged from the previous baseline.
  [effective: 2026-07-15] [learned: 2026-07-16]
- The margin figure was described as ready for the ICD, pending baseline at the next review.

## Fixture note

This file exists to exercise `protocol/routing-protocol.md` §Extract's verbatim fall-through: it is
*topically* responsive to a link-margin question but has rounded the committed value, so an
exact-wording or exact-value question cannot be answered faithfully from here. The precise figure
lives only in the transcript. This is precision loss in a paraphrase — the ordinary case — not a
contradiction between two claims.
