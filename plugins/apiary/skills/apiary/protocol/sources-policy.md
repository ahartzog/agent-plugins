---
layer: PROTOCOL
type: sources-policy
description: "Deposit path for primary source material — Sentinel-gated, no Parliament deliberation"
last_updated: 2026-07-20
codeowners: (read from hive.yml)
---

# Sources Policy

Primary source material — meeting transcripts, verbatim external documents (PDF/PPTX/DOCX/XLSX), raw notes — enters the Hive through a **deposit path** that bypasses Parliament deliberation. Sources are ground truth by definition; they are not claims that require adversarial validation.

Sources live in a **separate `sources/` directory with references from `knowledge/` back to the source** — this keeps the knowledge base lean while keeping originals discoverable. Sources do **not** live inside `knowledge/`.

---

## Design Principle

Parliament exists to validate *claims*. A transcript is a *primary source*, not a claim. Parliament should be able to *cite* sources when deliberating inbox contributions, but should not judge the source itself.

The distinction:
- **Claims** (inbox → Parliament → knowledge): "The architecture uses X." Requires Skeptic/Archivist/Cartographer deliberation.
- **Sources** (deposit → Sentinel → sources/): "Here is the verbatim transcript / document where X was discussed." Ground truth. No deliberation needed.

Learnings FROM sources still enter the knowledge base through the normal inbox→Parliament path. The collective judgment gate remains intact for curated knowledge.

---

## Two Deposit Paths

The Apiary owns the `sources/` **convention** (placement, taxonomy, LFS, index, Sentinel gate, protection model). Two paths populate it:

| Path | Handles | Mechanism | Owner |
|------|---------|-----------|-------|
| **Native Deposit** (this protocol) | Verbatim **text / markdown** — pasted transcripts, notes, `.txt`/`.md` files | Apiary Deposit workflow (`PROTOCOL/workflows.md`). Writes Apiary-schema inbox entries. | Apiary |
| **`/extract:ingest`** (delegated) | **Binary documents** — PDF, PPTX, DOCX, XLSX, images | The [`extract`](../../../../shallyburton/extract) plugin: parse → describe images → distill → place binary + write inbox entry. | `shallyburton/extract` |

**The Apiary does not reimplement binary extraction.** When a user asks to deposit a binary document, the Deposit workflow delegates to `/extract:ingest` rather than parsing the file itself. This keeps the Apiary's dependency surface light (bash + jq, no `uv`/`pymupdf`/vision models) and avoids duplicating a mature, tested pipeline.

See § Relationship to `extract` below for the interop boundary and a known schema-drift caveat.

---

## Directory Structure

Sources are organized by **doc-type subdirectory**, matching the taxonomy `extract` uses so both paths write to the same layout:

```
sources/
├── index.md            # Single source manifest (discoverability — Goal 9)
├── meeting-transcripts/ # Verbatim meeting/call transcripts (native Deposit)
├── document/            # Catch-all for ingested documents (extract default)
├── icd/                 # Interface control documents
├── whitepaper/
├── sow/                 # Statements of work
├── spec/
├── decision/            # Decision records
├── roster/              # People/team rosters
└── schedule/
```

**Blessed doc-types:** `meeting-transcripts`, `document`, `icd`, `whitepaper`, `sow`, `spec`, `decision`, `roster`, `schedule`. `document` is the catch-all when no keyword matches (this is `extract`'s default doc-type). `meeting-transcripts` is the native Deposit target for pasted transcripts.

Subdirectories are **created on demand** — a deposit into a doc-type that doesn't exist yet creates it. Hives may pre-declare a subset in `hive.yml.sources.subdirectories` (default `[meeting-transcripts]`); this is a documentation hint, not a constraint. The sparse-checkout pulls all of `sources/`, so no per-subdir enumeration is needed.

---

## Deposit Path (native)

The native Deposit workflow (dispatched from `PROTOCOL/workflows.md`) covers **verbatim text/markdown only**. Binary documents route to `/extract:ingest` (see § Relationship to `extract`).

```
Verbatim text / markdown source
  → Session agent writes to sources/{doc-type}/
  → Append row to sources/index.md (completion gate — Goal 9)
  → Sentinel scan (pre-push hook: PII, credentials, classification)
  → Direct push to {DEFAULT_BRANCH}
  → Available for Parliament citation
```

**Procedure:**

1. **Route by format first.** If the source is a binary document (PDF/PPTX/DOCX/XLSX/image) or a path to one, do NOT parse it here — hand off to `/extract:ingest <path> --hive <this-hive>`, which parses the file, LFS-tracks it in `sources/`, and writes a distilled inbox entry. Continue below only for verbatim text/markdown.
2. **Validate source material.** Confirm the content is verbatim, not a summary or interpretation. A summary is a claim — route it to the Contribute workflow instead.
3. **Determine doc-type + build frontmatter.** Pick `source_type` from the taxonomy (`meeting-transcripts`, `document`, `icd`, `whitepaper`, `sow`, `spec`, `decision`, `roster`, `schedule`) — default `meeting-transcripts` for a transcript, `document` otherwise. `source_type` is always identical to its target subdirectory name (all 9 values are, deliberately, both the enum value and the literal `sources/<value>/` dir — no type→dir mapping needed). Required frontmatter fields: `source_type`, `title`, `date` (the meeting/document date, not the deposit date), `recorder` (current git user). Optional: `participants`, `duration_minutes`, `session_id`, `classification`.
4. **Write the source file.** Path `sources/{source_type}/YYYY-MM-DD-{recorder}-{slug}.md`; frontmatter + verbatim content. Create the doc-type subdir if absent.
5. **Update the source index (completion gate — Goal 9).** Append a row to the single `sources/index.md` manifest: date, type, title, path, participants (if any), 3-5 topic keywords. The deposit is not complete until the row exists. If `sources/index.md` is missing, create it with the § Source Index schema.
6. **Sentinel scan.** The pre-push hook scans text sources on push. On a hit, follow `references/pre-push-sentinel.md` (redact, override, or hand back).
7. **Push.** Direct push to `{DEFAULT_BRANCH}`, same as inbox; rebase if needed.
8. **Offer extraction.** Ask whether to extract learnings into the knowledge base. If yes, read the deposited source and write inbox contributions with `source: "sources/{path}"` citations (this step follows normal inbox progressive-write discipline). If no, continue the session.

**No Parliament deliberation.** No Archivist re-formatting, no Skeptic challenge, no Chancellor verdict. The source is deposited as-is after Sentinel clearance.

**No auto-contribution.** Unlike inbox writes (autonomous per cross-cutting discipline), source deposits require explicit user intent — steps 1-7 are never triggered without the user asking. The agent does not fabricate sources. Only step 8's extracted learnings follow the autonomous inbox discipline.

---

## Frontmatter Schema (markdown sources only)

Text/markdown source files carry frontmatter validated against `assets/source-entry.schema.json`:

```yaml
---
source_type: meeting-transcripts   # meeting-transcripts | document | icd | whitepaper | sow | spec | decision | roster | schedule
title: "Weekly Sync — Ground Segment"
date: 2026-07-15
participants: [alice, bob, carol]  # GitHub usernames or identifiable names
duration_minutes: 45              # optional, for transcripts/recordings
recorder: jrivera                # who deposited this source
session_id: "abc123"              # optional Claude Code session ID
classification: UNCLASSIFIED      # required when hive.yml marking_required is true
---
```

Required fields: `source_type`, `title`, `date`, `recorder`.

**Binary sources cannot carry frontmatter.** A PDF/PPTX has no YAML header. Binary sources are described in `sources/index.md` (and by the `sources:` reference in the inbox entry `extract` produces) instead of by inline frontmatter. This is why the index is the authoritative discoverability record for binaries.

---

## Git LFS — required for binaries

Binary source files are tracked with **Git LFS**; text sources are tracked as normal git objects. This matches the `extract` plugin's LFS setup so the two deposit paths are consistent.

`.gitattributes` patterns (installed by `extract`'s `lfs_setup`, or add manually for a text-only Hive that later takes binaries):

```
*.pdf  filter=lfs diff=lfs merge=lfs -text
*.pptx filter=lfs diff=lfs merge=lfs -text
*.docx filter=lfs diff=lfs merge=lfs -text
*.xlsx filter=lfs diff=lfs merge=lfs -text
*.png  filter=lfs diff=lfs merge=lfs -text
*.jpg  filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
```

Text sources (`.md`, `.txt`) are **not** LFS-tracked — they diff cleanly and compress well in packfiles, and Parliament/Ask need to read them directly. A Hive that only ever holds pasted transcripts needs no LFS at all; LFS is set up lazily the first time a binary is ingested (`/extract:ingest` does this via `--no-lfs-setup` opt-out).

---

## Sentinel Gate

Sources pass through the same Sentinel scan as inbox contributions, with one important limitation for binaries:

1. **Pre-push hook** (Layer 0): Scans `sources/**` **text** files for PII, credentials, classification violations. Same `sentinel-patterns.json` pattern set.
2. **No Parliament Sentinel** (Layer 3 does not apply): Sources are not processed by Parliament, so they do not pass through the intake scan. The pre-push hook is the sole automated gate.

**Binary limitation (must be understood):** the pre-push hook greps file *content*. For an LFS-tracked binary, git presents a small text **pointer file**, not the document bytes — so the hook cannot scan a PDF's or PPTX's actual content for embedded PII/credentials/classified markings. **The depositor is responsible for the sensitivity of binary sources.** For the `extract` path, the extracted markdown (which the inbox entry is built from) *is* scannable and does pass through the normal inbox Sentinel path; the binary itself is not. Do not deposit a binary you have not confirmed is safe to store at the Hive's classification ceiling.

**Override semantics** are identical to inbox files: `sentinel_override` frontmatter records user-approved false positives (text sources only).

**Classification enforcement** follows the same rules as inbox:
- UNCLASSIFIED Hive: reject any classification marker in a text source file.
- Classified Hive: require correct markings on text source files at or below ceiling; reject above ceiling.

---

## Push Discipline

Sources push mode resolves as: `hive.yml.sources_push_mode` if set, else `hive.yml.push_mode`, else `direct`.

Same ergonomics as inbox: unique filenames prevent conflicts between concurrent sessions. Filename pattern: `YYYY-MM-DD-{recorder}-{slug}.<ext>`.

**Permission model:** `git add sources/*` is allowed for direct push (added to `.claude/settings.json` alongside `_inbox/*`).

---

## Source Index — Discoverability (Goal 9)

Per Design Goal 9 (Discoverability Guarantee), every content surface must be reachable from Ask and auditable by Audit. Sources are discoverable through **either** of two mechanisms:

1. **The source index** — a single `sources/index.md` manifest, maintained by the native Deposit workflow.
2. **Knowledge / inbox citation** — a `knowledge/**` or `_inbox/**` file's `sources:`/`source:` frontmatter that references the source path (this is how `extract`-ingested binaries become discoverable — their distilled inbox entry cites the binary).

A source is an **orphan** (Goal 9 violation) only if *neither* mechanism references it.

### Index File: `sources/index.md`

```yaml
---
domain: {hive-slug}
type: source-index
description: "Manifest of deposited sources — enables Ask to route source-answerable questions"
decay: slow
confidence: high
last_updated: {DATE}
classification: UNCLASSIFIED   # include only when marking_required
---
```

**Body:** one row per deposited source, across all doc-types:

| Date | Type | Title | Path | Participants | Key Topics |
|------|------|-------|------|--------------|------------|
| 2026-07-15 | meeting-transcripts | Weekly Sync — Ground Segment | meeting-transcripts/2026-07-15-jrivera-weekly-sync.md | alice, bob | antenna test results, R2 schedule slip |
| 2026-07-10 | icd | Payload ICD rev C | icd/icd-payload-rev-c-2026-07-10.pdf | — | power budget, mechanical envelope |

**Maintenance rules:**
- The **native Deposit** workflow appends a row after every successful deposit. This is a **completion gate** — a native deposit is not complete until the index row exists.
- **`extract`-ingested binaries** are discoverable via their distilled inbox/knowledge citation and do not require a manual index row; adding one is encouraged but Audit will not flag their absence as an orphan (the citation satisfies Goal 9).
- Rows are short (date, type, title, path, participants, 3-5 topic keywords). They exist for routing, not content reproduction.

### Reference-Library Pointer

The Hive's `knowledge/reference-library.md` gets ONE thin entry pointing at the manifest:

```
Sources | sources/index.md | meeting transcript, document, "what did we decide", "who said", ICD, spec, verbatim
```

This enables Ask to discover sources without scanning `sources/` speculatively.

### Ask Workflow Integration

When a user's question sounds like it might be answered by a primary source ("what did we decide about X in the meeting?", "what does the ICD say about Y?"):

1. Ask checks `reference-library.md` retrieval triggers → finds "Sources" entry
2. Loads `sources/index.md` (small, cheap)
3. Scans the manifest for topic/date/type/participant match
4. If match found → loads the specific source and answers from it (for a binary, note it is LFS-tracked and may need `git lfs pull`)
5. If no match → answers from knowledge files as normal, notes that no source corroborates

### Audit Check

Audit flags a source file as an orphan (WARN) only if it is referenced by **none** of: `sources/index.md`, any `_inbox/*.md` `sources:`/`source:` field, or any `knowledge/**/*.md` `sources:` field. It also flags index rows whose referenced file is missing (stale). See `references/mode-audit.md` § Source Index Integrity.

---

## What Sources Are NOT

- **Not knowledge.** Sources are raw material. They do not replace curated knowledge files.
- **Not searchable by default in Ask workflow.** Ask discovers sources via the manifest and reference-library pointer — it does not scan `sources/` directly.
- **Not processed by Parliament.** Parliament reads `_inbox/`, not `sources/`.
- **Not summarized.** The deposit path stores verbatim content. Summarization happens when a user or agent extracts learnings into an inbox contribution.

---

## Parliament Citation Capability

During deliberation, Parliament agents (Skeptic, Cartographer) may cross-reference `sources/` to corroborate or challenge claims:

- **Skeptic:** "Is this claim sourced?" → can check whether a source in `sources/` corroborates it.
- **Cartographer:** "Does this contradict existing knowledge?" → can check sources for the ground truth.

Citation format in deliberation output:
```
[source: sources/meeting-transcripts/2026-07-15-jrivera-weekly-sync.md, line 42]
```

This is advisory — citations strengthen or weaken confidence but do not auto-resolve verdicts.

---

## Who Writes Sources

| Actor | When | How |
|-------|------|-----|
| Session agent (native Deposit) | User pastes / points to a **text** transcript or note | Agent formats, validates frontmatter, appends index row, pushes |
| `/extract:ingest` | User ingests a **binary document** (PDF/PPTX/DOCX/XLSX) | extract parses, LFS-places the binary in `sources/<doc-type>/`, writes a distilled inbox entry |
| Zoom/meeting-notes skill | After transcribing a recording | Writes the transcript to `sources/meeting-transcripts/` via the native path, optionally distills to `_inbox/` |
| Human (direct commit) | Manual deposit | Branch + push (no PR required for `sources/`); must add an index row for text sources |

---

## Relationship to `extract`

The [`shallyburton/extract`](../../../../shallyburton/extract) plugin is the **reference tool for binary-document ingestion**. The Apiary delegates to it rather than duplicating PDF/PPTX/DOCX parsing.

**Boundary:**
- Apiary native Deposit → verbatim **text/markdown**, Apiary-schema inbox entries.
- `/extract:ingest` → **binary documents**, its own extraction pipeline (image description, dedup, SHA-256 content addressing, LFS), writing its own inbox entries.

**Known schema drift (interop caveat, not resolved here):** `extract`'s inbox entries use `tag: [list]`, `sources: [{path, sha256}]`, and `created_at`, whereas the Apiary inbox schema (`assets/inbox-entry.schema.json`) expects `tag:` string, `source:` string, and `date`. The two are not currently guaranteed to validate against each other. This is intentionally **out of scope** for this protocol — `extract` is an independent plugin and may keep its own format. Reconciling the schemas (or teaching Parliament's Frontmatter Normalizer the `extract` field shapes) is tracked as a separate coordination item with the `extract` maintainer. Until then, a Hive using `/extract:ingest` should confirm its distilled inbox entries are promoted correctly by Parliament.

---

## Size and Retention

Documents and transcripts can be large. Unlike knowledge files, sources have no size budget enforced by Audit. However:

- **Binaries use Git LFS** (see § Git LFS above); text sources are normal git objects.
- **Retention:** Sources are permanent unless a Hive's codeowners choose to archive old sources. No automated cleanup.
- **Sparse checkout:** All of `sources/` is in the sparse-checkout set so Parliament can cite sources, but individual sessions may skip loading a large binary unless a specific claim needs it.
