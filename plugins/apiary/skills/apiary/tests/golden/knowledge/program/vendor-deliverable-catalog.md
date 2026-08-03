---
domain: program
type: index
description: "Synthetic catalog of a Box-hosted vendor deliverable — fixture for the golden RLDP tool-missing degradation case."
decay: medium
confidence: high
last_updated: 2026-05-15
sources:
  - url: "https://example.app.box.com"
    type: box
---

# Vendor Deliverable Catalog (Box)

Single row, ID-addressed absolute URL. Fixture for golden case 8 — resolving this row requires
`box-skill` (`protocol/tool-tiers.md` § Store Kind → Tool). The golden case prompt directs the
subagent to treat `box-skill` as not installed for the exercise, regardless of what is actually
available in the environment running the case, so the case is reproducible everywhere.

| Document | Location | covers | doc_type | authority | source_org | Last Modified |
|---|---|---|---|---|---|---|
| Demo Corp CDR Chart Package | `https://example.app.box.com/file/998877665544` | CDR chart package, review board comments, action item dispositions | vendor-deliverable | delivered | Demo Corp | 2026-05-10 |
