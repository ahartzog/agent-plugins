---
domain: ground-segment
type: index
description: "Synthetic document catalog for the golden RLDP test suite — SharePoint-backed, exercises authority ranking, store-relative folder rows, and covers matching."
decay: medium
confidence: high
last_updated: 2026-06-01
sources:
  - url: "https://example.sharepoint.com/sites/demo/Shared%20Documents/"
    type: sharepoint
---

# Ground Segment Document Catalog

Rows are store-relative to the SharePoint root declared above unless a row carries its own
absolute URL. Fixture data for `tests/golden/cases.md` — case 2 (authority conflict), case 3
(store-relative folder row), case 6 (`covers` absent), case 7 (`covers` sufficient, no fetch).

The working-draft row is listed **before** its formal counterpart deliberately (case 2): an
agent that picks by row order rather than the `authority` column would get case 2 wrong, which
is the whole point of a case built to catch a row-order regression.

| Document | Location | covers | doc_type | authority | source_org | Last Modified |
|---|---|---|---|---|---|---|
| Space-to-Ground Link Budget — Working Draft | `02 - Systems Engineering/Working Docs/` | link margin requirements, S-band uplink budget, X-band downlink budget, antenna gain assumptions | specification | working | | 2026-05-20 |
| PROJ-123 Space-to-Ground Link Budget Spec | `02 - Systems Engineering/Link Budget/` | link margin requirements, S-band uplink budget, X-band downlink budget, antenna gain assumptions | specification | formal | | 2026-03-02 |
| Ground MTP Draft | `03 - Test/Working Docs/` | MTP architecture, deployment topology, environment tiers | plan | working | | 2026-04-06 |
| 2.1_2.4 - CDR Ground Segment Design (Internal).pptx | `04 - CDR/Ground Segment/` | | analysis-report | baseline | | 2026-02-14 |
| PROJ-123 Ground Station RF Interface Requirements | `01 - Requirements/` | ground station RF link requirements, EIRP thresholds, G/T requirements | requirements | formal | | 2026-01-20 |
