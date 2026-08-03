---
domain: ground-segment
type: index
description: "Synthetic catalog with store-relative rows and no declared store root — fixture for the golden RLDP no-match/unresolvable-pointer case."
decay: medium
confidence: medium
last_updated: 2026-05-01
---

# Legacy Ground Interface Catalog

Deliberately missing `sources[]`. Rows below name a folder location but no store root is
declared anywhere in this file's frontmatter, so none of them resolve — this is the fixture
for golden case 4 (`tests/golden/cases.md`).

| Document | Location | covers | doc_type | authority |
|---|---|---|---|---|
| Legacy Command Format Register | `Archive/Legacy Interfaces/` | pre-2025 command format, old interface register | reference | working |
