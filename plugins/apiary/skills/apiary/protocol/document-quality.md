---
layer: PROTOCOL
type: schema-spec
description: "Quality and type classification for external source documents referenced in Hive knowledge catalogs. Defines doc_type and authority fields for source entries."
last_updated: 2026-07-30
codeowners: (read from hive.yml)
---

# Document Quality & Type Classification

When a Hive catalogs external documents (SharePoint files, Confluence pages, vendor deliverables), each entry should carry classification fields. The three required fields are **doc_type** (what kind of document), **authority** (how much citation trust), and **covers** (what the document is about). Optional fields — **source_org**, **scope**, **supersedes**, and **discovered_via** — provide additional routing context and provenance.

> **Shared taxonomy:** The `doc_type` and `authority` enums, `source_org`, `scope`, `supersedes`, and `discovered_via` here are shared with the [Second Brain document-quality protocol](../../../../second-brain/skills/second-brain/references/document-quality.md). The two renderings differ in framing (this one is the multi-Hive PROTOCOL spec; Second Brain's is trimmed for single-user agents) but the field definitions and enum values must stay identical. Any change to a field or enum here must be upstreamed to the other, and vice versa.
>
> **`covers` was adopted into Second Brain on 2026-09-08** (second-brain 2.2.0). It is no longer Apiary-only: the field definition, the write-the-subjects rule, and the 3-8 term budget are now shared, and a change to any of them must be upstreamed to the other rendering. The two differ only in worked examples.

## Fields

### doc_type

What kind of document is this? Agents use this to route question types to the right class of source.

**Base taxonomy** (all Hives):

| doc_type | Description | Example |
|----------|------------|---------|
| `cdrl` | Configuration-managed deliverable with a document number (e.g., KP-SYS-0004) | KP-SYS-0014 MDP ICD |
| `icd` | Interface Control Document (signed or config-managed) | Acme_to_UDL_ICD-v1.0.docx |
| `rfc` | Request for Comments — design proposal (draft or approved) | KP-310 Plan Lifecycle RFC |
| `prd` | Product Requirements Document | KP-SYS-0001 C2 PRD |
| `sdd` | Software Design Document | Ground Segment SDD v1.0 |
| `specification` | Formal specification or standard (requirements, test, performance) | Ground Segment Specification Rev D |
| `requirements` | Requirements document, TRD, RVM, verification matrix | TRD v1.3b, RVM v1.4 |
| `trade-study` | Trade study or course-of-action analysis | Lonestar Viability Assessment |
| `conops` | Concept of Operations | Launch CONOPS |
| `test-document` | Test plan, procedure, or report | EIT Test Plan, SAT Report |
| `analysis-report` | Engineering analysis, simulation results, or technical report | Separation Analysis, CLA Report |
| `plan` | Program or technical plan (SDP, IMS, MTP, etc.) | KP-PL-0003 IMS, Ground MTP |
| `schedule` | Project schedule (.mpp, Gantt, milestone tracker) | PCBA Schedule, IMS |
| `procedure` | Step-by-step operational or test procedure | Workmanship Vibration Test Procedure |
| `vendor-deliverable` | Formal delivery from external vendor/partner | Orbital Dynamics CDR charts, Vantage Aerospace IMS |
| `tracker` | Living spreadsheet/matrix (action items, giver-receiver, RACI) | Program Action Tracker, Artifact RACI |
| `data` | Raw data files (CSV, telemetry, simulation output) | DRM-A trajectory CSV |
| `meeting-notes` | Meeting minutes, IPT notes, weekly readouts — temporal records | Program bi-weekly notes, customer weekly |
| `working` | Useful reference not fitting other categories, not formally reviewed | Working notes, draft slides |

**Domain extensions:** The base taxonomy above is weighted toward program/CDRL contexts. Operational, enterprise, and platform domains should **extend rather than shoehorn**. Add domain-specific `doc_type` values in the catalog's frontmatter under `doc_type_extensions`. Examples:
- Meridian Platform: `runbook`, `design-doc`, `postmortem`
- ERP/BizSys: `dashboard-spec`, `integration-spec`, `operational-report`
- Cyber/accreditation: `vulnerability-finding`, `stig-checklist`, `authorization-package`

### authority

How much citation trust does this document carry? Agents use this to decide whether to cite directly or add caveats.

| authority | Label | Agent behavior |
|-----------|-------|---------------|
| `formal` | Config-managed, signed, or numbered (KP-/CDRL) | Cite directly. This is the authoritative source. |
| `baseline` | Milestone-frozen (CDR/PDR submitted, gov-reviewed) | Cite directly with milestone date. May be superseded by later revisions. |
| `delivered` | Vendor/partner formal delivery with tracking | Cite with source organization noted. |
| `working` | Not formally reviewed or approved | Caveat: "working document — verify against authoritative source." |

**IMPORTANT:** `authority` is a **strict 4-value enum**, not a free-text field. Do not put organization names, author names, or compound values here. Use `source_org` (below) for the responsible organization.

**Note:** `authority` applies to the external document, not the knowledge file that references it. A knowledge file may have `confidence: high` while referencing a `working` authority document if the agent has validated the information through multiple sources.

### covers

What is this document **about** — the topical content an agent matches a question against. `doc_type` and `authority` say what class of document it is and how much to trust it; neither says what is inside it. `covers` is that field.

This is the catalog's equivalent of a reference-library `Triggers` column, and it carries the same weight. Routing arrives at a catalog and scans rows for the query terms (`protocol/routing-protocol.md` §Extract); a row whose only free text is a filename can be matched only by filename. `(U) 2.1_2.4 - CDR Ground Segment Design (CUI).pptx` will not match "how does flight dynamics hand off to T&C" no matter how directly the document answers it.

**Write the subjects, not the role.** Name the topics, systems, interfaces, and terms a reader would search for — the words that would appear in a question this document answers.

| Good | Weak — and why |
|---|---|
| `Transfer orbit, ground ops workflow, phasing burn sequence` | `Mission thread doc` — restates `doc_type` |
| `Power budget, mechanical envelope, connector pinout` | `Interface document for the payload` — role, not content |
| `CDR action items, dispositions, owners, due dates` | `Post-CDR retrospective` — says what the meeting was, not what is in the file |

- **Length:** a phrase list, not a sentence. Aim for 3-8 terms; keep it inside one table cell. A row needing more belongs in block form or a knowledge file.
- **`covers` also decides fetches.** A row with real coverage terms can *be* the answer for a scoping question ("which document defines X"), which avoids a fetch entirely — the Goal 2 economy (`design-goals.md` §2). A row without it forces the agent to open the document to find out whether the document was relevant.
- **Do not paste content.** `covers` is a topic list, not a summary of findings. Values, wording, and conclusions live in the document; reproducing them here is the duplication Goal 1 prohibits.
- **Folder-level rows** describe the class of document in the folder (`ICDs for space-to-ground and payload interfaces`), since no single document is named.

### source_org (optional)

The organization or team responsible for the document. Useful for vendor deliverables and cross-org interfaces.

| source_org | When to use |
|------------|------------|
| Free-text string (org name) | When the document originates from an external vendor, partner, or government entity |
| Omit | When the document is internal to the program |

Examples: `Orbital Dynamics`, `Nova Launch`, `Vantage Aerospace`, `Fictional National Lab`, `Government Customer`, `Horizon Space`. Do NOT put this in the `authority` column.

### scope (optional)

Where in the engineering lifecycle this document sits. Agents use this to assemble complete answers that span multiple authority levels.

| scope | Description |
|-------|------------|
| `requirements` | What the system must do (specs, PRDs, TRDs, RVMs) |
| `design` | How the system does it (CDR decks, SDDs, architecture docs) |
| `analysis` | Whether the design works (trade studies, FEM, thermal, link budgets) |
| `verification` | Proof that it works (test plans, test reports, inspection records) |
| `operations` | How to run it (CONOPS, procedures, runbooks, MOPs) |

A single question like "What are the thermal constraints?" may need a `requirements` doc (thermal spec), a `design` doc (CDR thermal section), and an `analysis` doc (thermal margins report). Agents should gather across scope values when answering cross-cutting questions.

### supersedes (optional)

Pointer to the prior version of this document. Enables agents to trace revision chains and prefer the latest.

Format: free-text string identifying the prior version. Examples:
- `KP-SYS-0004 Rev A` (superseded by Rev C)
- `CDR 12.8.2025 Customer Drop` (superseded by `03.11.2026 Final AI Incorporated`)
- `IMS RevB 08.07.2025` (superseded by `IMS RevC 11.20.2025`)

When a superseded document still exists in the catalog (e.g., as a baseline snapshot), mark it `authority: baseline` and note the supersession. Agents should prefer the latest version for "current status" questions but may cite the baseline version for "what was decided at CDR" questions.

### discovered_via (optional)

How the row entered the catalog. It records **review status, not `covers` quality** — the `covers` text is content-derived in both cases (see § covers).

| discovered_via | Meaning |
|----------------|---------|
| `trawl` | A human trawl placed this row. Default; implied when the field is absent. |
| `search` | A live store search discovered and promoted this row (`protocol/routing-protocol.md` §Search). No human has yet reviewed the document's placement in the corpus. |

A `discovered_via: search` row is a full catalog row — it was promoted only because the document was opened, so its `covers` came from the document, not from a filename. The marker does not weaken the row; it flags that its placement is unreviewed, so Parliament's Cartographer can surface it for a look.

## Trawling Heuristics

When cataloging documents from a large file store (SharePoint, Google Drive, Confluence), apply these gates **in priority order** — stop at first match:

1. **Has a document number** (e.g., KP-SYS-####, KP-PL-####) → `doc_type` per the number's series, `authority: formal`
2. **Lives in a milestone review folder** (e.g., `CDR/`, `PDR/`, `Technical Review/`) → classify by content, `authority: baseline`
3. **Has ICD in the name or is a signed interface document** → `doc_type: icd`, `authority: formal`
4. **Vendor/partner formal delivery** (Orbital Dynamics, Vantage Aerospace, Nova Launch, Fictional National Lab delivery folders) → `doc_type: vendor-deliverable`, `authority: delivered`
5. **Would an engineer cite this in a formal deliverable?** → classify by content type, `authority: working`
6. **None of the above** → do not catalog

### Skip criteria (do not catalog):
- Files in `/Archive/` or `/archive/` subdirectories (reference the current version instead)
- Duplicate files (same name with user suffix like `-username-1234`)
- Raw binary/CAD files unless they represent a specific deliverable
- Images, screenshots, or photos unless they are standalone deliverables
- Empty folders

### Hive-specific gate ordering

Hives may reorder or extend these gates. For example, a cyber-focused Hive might insert "Has STIG ID or CVE reference → `doc_type: vulnerability-finding`" at gate 3. Document any gate customization in the Hive's catalog frontmatter.

### Reuse by live search

`protocol/routing-protocol.md` §Search reuses these same path-based inference rules to rank live store search candidates, rather than inventing a parallel scheme. The rules apply identically: a document number ⇒ `formal`, a milestone-review folder ⇒ `baseline`, a vendor delivery folder ⇒ `delivered`. But inference from a path is sufficient only to **select** a candidate, never to **describe** a document — so it must not populate `covers`. `covers` is content-derived and is filled only when the document is opened (the promotion gate in §Extract; `references/external-retrieval-search-design.md` § Why promotion requires a read).

## Question-Type Routing

When an agent has multiple documents covering the same topic, use `authority` and recency together:

| Question pattern | Preferred source |
|-----------------|-----------------|
| "How is X designed?" | `baseline` or `formal` (milestone-frozen is authoritative for design) |
| "What's the current status of X?" | Most recent `working` or `delivered` document |
| "What are the requirements for X?" | `formal` (config-managed requirements doc) |
| "What did vendor Y deliver?" | `delivered` authority documents |
| "What was decided at CDR?" | `baseline` from CDR milestone folder |
| "Is X working right now?" | **Documents are not the source of truth.** Probe the live system first (REST API, DB query, log tail, MCP tool). Fall back to document catalog only if live probe is unavailable. |

How a `discovered_via: search` row ranks against an authored one is a routing decision, not a schema one: `protocol/routing-protocol.md` §Prefer owns it.

## Applying to Knowledge Files

These fields go on **source entries** within document catalog knowledge files, not on the knowledge file's own frontmatter. Example:

```yaml
# In a document catalog knowledge file
sources:
  - doc: "KP-SYS-0004 Space-to-Ground ICD"
    path: "06 - Ground Segment/ICDs/"
    covers: "uplink/downlink framing, command formats, link margins"
    doc_type: icd
    authority: formal
  - doc: "Ground MTP Design Spec"
    path: "02 - Systems Engineering/Ground Delta CDR/Working Docs/"
    covers: "MTP architecture, deployment topology, environment tiers"
    doc_type: specification
    authority: working
```

For inline catalog entries (markdown tables), use this column order. `source_org` is included when vendor/external documents are present; omit it for purely internal catalogs.

```markdown
| Document | Location | covers | doc_type | authority | source_org | Last Modified | Author |
|----------|----------|--------|----------|-----------|------------|---------------|--------|
| KP-SYS-0014 MDP ICD | `10 - Config Mgmt/` | MDP-to-ground interface, message formats, timing | cdrl | formal | | 2026-01-14 | Morgan Lee |
| Orbital Dynamics Aurora CDR | `04.01 - Orbital Dynamics/CDR/` | bus design, power/thermal margins, separation sequence | vendor-deliverable | delivered | Orbital Dynamics | 2025-07-14 | Priya Shah |
| Ground MTP Draft | `Working Docs/` | test campaign phases, entry/exit criteria, environments | plan | working | | 2026-04-06 | Jamie Rivera |
```

`covers` sits next to `Document` because they are read together — the name identifies, the coverage matches. Everything after is metadata used to choose between rows that already matched.

**Existing catalogs use several names for this column** — `Purpose`, `One-liner`, `Note`, `Contents`, `Covers`. They are the same field arrived at independently. `covers` is the canonical name; rename on next edit rather than in a bulk pass, and prefer topical content over role wording when rewriting (a `Purpose` cell reading "Post-CDR retrospective" should become the subjects the file actually holds).

**Common mistakes to avoid:**
- Do NOT put organization names in the `authority` column — use `source_org`
- Do NOT put compound values like `cdrl, formal` in `doc_type` — these are separate fields
- Do NOT use `deprecated` or `superseded` as a `doc_type` — use `supersedes` to link versions
- `authority` is always one of: `formal`, `baseline`, `delivered`, `working`
- Do NOT restate `doc_type` in `covers` ("ICD document") — `covers` holds subjects, not the document's class
