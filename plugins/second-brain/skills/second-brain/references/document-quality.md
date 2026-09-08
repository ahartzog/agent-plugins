# Document Quality & Type Categorization

When your domain agent catalogs external documents (SharePoint files, Confluence pages, vendor deliverables) in `type: index` knowledge files, each entry should carry categorization fields. The three required fields are **doc_type** (what kind of document), **authority** (how much citation trust), and **covers** (what the document is about). Optional fields — **source_org**, **scope**, and **supersedes** — provide additional routing context.

> **Note:** This taxonomy is shared between the second-brain and apiary plugins — keep the two copies in sync. `covers` was adopted here from the apiary rendering on 2026-09-08; the field definition must stay identical in both.

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

### covers

What is this document **about** — the topical content an agent matches a question against. `doc_type` and `authority` say what class of document it is and how much to trust it; neither says what is inside it. `covers` is that field.

This is the catalog's equivalent of a reference-library `Triggers` column, and it carries the same weight. An agent arriving at a catalog scans rows for the query terms; a row whose only free text is a filename can be matched only by filename. `2026 EOB Batch 3.pdf` will not match "what did the cardiology visit actually cost" no matter how directly the document answers it.

**Write the subjects, not the role.** Name the topics, accounts, providers, and terms a reader would search for — the words that would appear in a question this document answers.

| Good | Weak — and why |
|---|---|
| `Deductible, out-of-pocket max, in-network tiers, FSA eligibility` | `Benefits document` — restates `doc_type` |
| `Roof replacement scope, shingle spec, warranty terms, payment schedule` | `Contract for the roof` — role, not content |
| `Cost basis, capital improvements, holding periods, wash-sale dates` | `Tax reference` — says what the file is for, not what is in it |

- **Length:** a phrase list, not a sentence. Aim for 3-8 terms; keep it inside one table cell. A row needing more belongs in block form or its own knowledge file.
- **`covers` also decides fetches.** A row with real coverage terms can *be* the answer for a scoping question ("which document defines X"), which avoids opening the document at all. A row without it forces the agent to open the document to find out whether the document was relevant.
- **Do not paste content.** `covers` is a topic list, not a summary of findings. Values, wording, and conclusions live in the document; reproducing them here is the duplication DESIGN-GOALS §1 prohibits.
- **Folder-level rows** describe the class of document in the folder (`homeowner and auto policies, declarations pages, claim records`), since no single document is named.

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
| Document | Location | doc_type | authority | covers | source_org | Last Modified |
|----------|----------|----------|-----------|--------|------------|---------------|
| Home Insurance Policy 2026 | `Household/Insurance/` | record | formal | dwelling limit, deductible, wind/hail exclusions, RV coverage | State Farm | 2026-01-14 |
| Kitchen Reno Final Punch List | `Household/Projects/` | deliverable | delivered | punch items, owners, retainage release, warranty start | Acme Remodeling | 2025-07-14 |
```

**Common mistakes to avoid:**
- Do NOT put organization names in the `authority` column — use `source_org`
- Do NOT put compound values like `record, formal` in `doc_type` — these are separate fields
- `authority` is always one of: `formal`, `baseline`, `delivered`, `working`
- Do NOT restate `doc_type` in `covers` — "insurance policy" is the class, not the coverage terms
