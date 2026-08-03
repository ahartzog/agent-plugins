---
domain: program
type: index
description: "Synthetic catalog spanning two stores but declaring a root for only one — fixture for the golden RLDP partial-store-root case (optional extra)."
decay: medium
confidence: medium
last_updated: 2026-05-01
sources:
  - url: "https://example.sharepoint.us/sites/demo/Shared%20Documents/"
    type: sharepoint
---

# Mixed-Store Program Catalog

Two rows, two stores — SharePoint (root declared above) and GHE (no root declared anywhere in
this file). The GHE row is unresolvable even though the file overall looks store-rooted.
Fixture for golden case 9 (optional extra) — a mixed-store catalog declaring only one of two
roots must not let the declared root paper over the undeclared one.

| Document | Location | covers | doc_type | authority | source_org |
|---|---|---|---|---|---|
| Ground SDD Rev B | `03 - Design/` | ground segment architecture, subsystem interfaces | sdd | baseline | |
| orbital-planner README | `github.com/example-org/orbital-planner` | mission-planning scheduler design notes, contact window algorithm | working | working | |
