# Document Quality & Type Categorization

When your domain agent catalogs external documents (SharePoint files, Confluence pages, vendor deliverables) in `type: index` knowledge files, each entry should carry categorization fields. The two required fields are **doc_type** (what kind of document) and **authority** (how much citation trust). Optional fields — **source_org**, **scope**, and **supersedes** — provide additional routing context.

> **Note:** This taxonomy is shared between the second-brain and apiary plugins — keep the two copies in sync.

## Fields

### doc_type

What kind of document is this? Agents use this to route question types to the right class of source.

| doc_type | Description | Example |
|----------|------------|---------|
| `reference` | Stable reference material or manual | Homeowner's manual |
| `guide` | How-to, runbook, or walkthrough | "Filing an insurance claim" writeup |
| `spec` | Specification or design document | Home network diagram + spec |
| `proposal` | Proposal, RFC, or decision doc | "Refinance vs. recast" decision doc |
| `report` | Analysis, findings, or summary | Home energy audit report |
| `record` | Official record: policy, contract, statement, receipt | Home insurance policy |
| `plan` | Plan or schedule | Kitchen reno project plan |
| `procedure` | Step-by-step procedure or checklist | Winterization checklist |
| `deliverable` | Formal delivery from a vendor/contractor/service | Contractor's final punch list |
| `tracker` | Living spreadsheet/matrix | Home projects tracker |
| `data` | Raw data files (CSV, exports) | Bank transaction export |
| `notes` | Meeting notes or working notes | Contractor walkthrough notes |
| `correspondence` | Email/letter threads | Warranty claim email thread |

**Domain extensions:** The base taxonomy above is weighted toward general/household contexts. Specialized domains (engineering, legal, medical) should **extend rather than shoehorn**. Add domain-specific values in the catalog's frontmatter under `doc_type_extensions`. Examples:
- Engineering: `runbook`, `design-doc`, `postmortem`
- Legal/finance: `statement`, `filing`, `agreement`

### authority

How much citation trust does this document carry?

| authority | Label | Agent behavior |
|-----------|-------|---------------|
| `formal` | Signed, numbered, or officially issued | Cite directly. |
| `baseline` | Frozen at a review milestone; may be superseded | Cite with milestone date. May be superseded. |
| `delivered` | Formal delivery from an outside party | Cite with source organization noted. |
| `working` | Draft / not formally reviewed | Caveat: verify against authoritative source. |

**IMPORTANT:** `authority` is a **strict 4-value enum**. Organization names go in `source_org`, not here.

### source_org (optional)

The organization or team responsible for the document. Free-text string. Examples: `State Farm`, `Acme Remodeling`, `Fidelity`, `Kaiser`.

### scope (optional)

Where in the document's lifecycle this material sits.

| scope | Description |
|-------|------------|
| `requirements` | What is needed |
| `design` | How it is put together |
| `analysis` | Whether it holds up |
| `verification` | Proof that it works |
| `operations` | How to run or maintain it |

### supersedes (optional)

Pointer to the prior version. Free-text string identifying the prior revision.

## Trawling Heuristics

When cataloging documents from a large file store, apply these gates in priority order — stop at first match:

1. **Has a formal reference/policy number** → classify by content, `authority: formal`
2. **Lives in a review/milestone folder** → classify by content, `authority: baseline`
3. **Is an agreement/contract by name** → `doc_type: record`, `authority: formal`
4. **Formal delivery from an outside party** → `doc_type: deliverable`, `authority: delivered`
5. **Would you cite this later?** → classify by content type, `authority: working`
6. **None of the above** → do not catalog

Skip: archive folders, user-suffix duplicates, raw binary/CAD, screenshots, empty folders.

## Question-Type Routing

| Question pattern | Preferred source |
|-----------------|-----------------|
| "How is X designed?" | `baseline` or `formal` |
| "What's the current status of X?" | Most recent `working` or `delivered` |
| "What are the requirements for X?" | `formal` |
| "What did vendor Y deliver?" | `delivered`, filter by `source_org` |
| "Is X working right now?" | Documents are not the source of truth. Probe live system first (REST, DB, logs, MCP tool). Document catalog as fallback only. |

## Inline Catalog Format

```markdown
| Document | Location | doc_type | authority | source_org | Last Modified | Author |
|----------|----------|----------|-----------|------------|---------------|--------|
| Home Insurance Policy 2026 | `Household/Insurance/` | record | formal | State Farm | 2026-01-14 | |
| Kitchen Reno Final Punch List | `Household/Projects/` | deliverable | delivered | Acme Remodeling | 2025-07-14 | |
```

**Common mistakes to avoid:**
- Do NOT put organization names in the `authority` column — use `source_org`
- Do NOT put compound values like `record, formal` in `doc_type` — these are separate fields
- `authority` is always one of: `formal`, `baseline`, `delivered`, `working`
