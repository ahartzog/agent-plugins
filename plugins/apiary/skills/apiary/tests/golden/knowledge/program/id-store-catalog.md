---
domain: program
type: index
description: "Synthetic catalog of ID-addressed (Quip) documents — fixture for the golden RLDP ID-addressed-store case. Every row is an absolute URL; no store root applies."
decay: medium
confidence: high
last_updated: 2026-06-01
sources:
  - type: quip
---

# Program Decision Log (Quip)

Every row is an absolute, opaque-ID URL — there is no path to join against a root, so no
`sources[].url` root is declared here (the `sources[]` entry above names the store kind only,
per `protocol/knowledge-schema.md` § Store Roots — "a catalog whose rows are all absolute URLs
needs no root"). Fixture for golden case 5.

| Document | Location | covers | doc_type | authority | Last Modified |
|---|---|---|---|---|---|
| IPT Decision Log — May 2026 | `https://example.quip.com/NieRAn8pvonB` | IPT action items, decision log, CDR follow-ups | meeting-notes | working | 2026-05-28 |
