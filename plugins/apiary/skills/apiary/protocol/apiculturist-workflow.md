# Apiculturist — Registry Reconciliation Agent

**Purpose:** Keep a Hive and the [Hive Mind Registry](https://confluence.meridian.example/pages/viewpage.action?pageId=100000001) in sync, in both directions, on every Parliament run.
**Dispatched from:** `protocol/custodian-workflow.md` §1.4

The registry is the federation's index: it is how a Hive learns its siblings exist, and how every
*other* Hive learns this one exists. A row written once at create time and never revisited goes
stale the first time a Hive upgrades, changes codeowners, or moves Slack channels — and a Hive
created before registration existed would be invisible forever. The Apiculturist closes that loop
on every Parliament run.

---

## Dispatch Contract

Parliament dispatches the Apiculturist as a **subagent** (§1.4 of `custodian-workflow.md`). It may run
concurrently with Steps 1.2/1.3 — it has no data dependency on the work set.

**Inputs handed to the agent** (nothing else — it does not receive inbox contents):

- `{HIVE_SLUG}`, `{HIVE_PURPOSE}`, `{REPO}` (`org/repo`, derived from `remote`), `{MAX_LEVEL}`
  (`classification.max_level`; absent block ⇒ `UNCLASSIFIED`), `{CODEOWNERS_CSV}`, `{SLACK_CHANNEL}`,
  `{UPSTREAM_VERSION}` — all read from `hive.yml`
- `{REGISTRY_URL}` and its `{REGISTRY_PAGE_ID}` from `hive.yml.confluence_registry`
- The absolute path to `hive.yml` — the agent's only write target on disk

**Outputs:** the ≤3-line summary in §5, plus (a) an edited `siblings:` block in `hive.yml`, left
**staged but uncommitted** for Parliament's §6.3 housekeeping commit, and (b) at most one Confluence
page update.

**The Apiculturist MUST NOT** read `_inbox/`, `knowledge/`, or `sources/`; MUST NOT commit, push, or
otherwise touch git (§6.3 owns that); MUST NOT write any file other than `hive.yml`.

**Ungated.** Unlike the read-only §1.4 it replaces, the Apiculturist runs on **every** Parliament,
whether or not the work set is empty. Rationale: an unregistered or stale-rowed Hive is *most likely*
to be one with a quiet inbox — exactly the case the old work-set gate skipped. Cost to Parliament's
main context is the 3-line summary regardless of how large the registry grows.

**If `hive.yml.confluence_registry` is absent:** return
`registry: not configured — run /apiary upgrade to backfill (mode-upgrade.md, pre-2.5.0 migration)`
and exit 0. Never guess the page ID.

### Federation opt-outs

Two independent switches in `hive.yml.federation`, both defaulting to `true` (so a Hive with no
`federation:` block behaves exactly as it always has):

| Setting | `false` means |
|---|---|
| `federation.register` | Never write this Hive's own row. §2 is skipped entirely. |
| `federation.cross_hive_routing` | This Hive never suggests contributions to siblings, so the roster has no consumer. §1 is skipped entirely. |

They map one-to-one onto the two halves of this agent, which is why those halves are specified
independently:

- `register: true`, `cross_hive_routing: true` → run §1 and §2 (the default)
- `register: false`, `cross_hive_routing: true` → §1 only — consume the federation without being
  listed in it
- `register: true`, `cross_hive_routing: false` → §2 only — stay discoverable without routing
  anything outward
- both `false` → **do not dispatch the Apiculturist at all.** Parliament skips §1.4 and makes no
  Confluence call whatsoever. Report `registry: disabled (federation opt-out)`.

**`register: false` MUST NOT delete an already-published row.** Opting out means "stop maintaining my
row," not "retract it" — silently deleting a row that other Hives' cached rosters already reference is
destructive, and retraction is a human decision. Audit Step 4c reports the mismatch (`row present but
federation.register is false`) so a codeowner can remove it deliberately.

**A `false` switch is not a security control.** These govern *this* Hive's outbound behavior. They do
not stop another Hive from listing itself, and they do not prevent another Hive from suggesting
content toward this one. Classification enforcement remains the direction guard's job
(`custodian-workflow.md` §2.1 step 5) — never reach for `federation` to keep controlled content in.

---

## 1. Pull — Sibling Roster

**Skip this section entirely if `federation.cross_hive_routing` is `false`** — nothing consumes the
roster, so refreshing it is pointless work against a shared page. Report `siblings: skipped (opted out)`.

1. Read the page storage body: `confluence edit {REGISTRY_PAGE_ID}` (a READ op despite the name).
2. Parse `<tbody>` into `{slug, purpose, repo, classification}` for every row **except** `{HIVE_SLUG}`.
   Normalize the Max Classification cell's text to the `hive.schema.json` enum:

   | Cell text | Enum value |
   |---|---|
   | `UNCLASSIFIED` | `UNCLASSIFIED` |
   | `CUI / ITAR` (or `CUI`) | `CUI` |
   | `FOUO (legacy)` (or `FOUO`) | `FOUO` |
   | anything else, or unparseable | `UNCLASSIFIED` |

   The final row is a deliberate **fail-safe**: `UNCLASSIFIED` is the most restrictive assumption for
   the cross-hive direction guard, which refuses to route controlled content toward a lower ceiling.
   Guessing high would be the unsafe direction.
3. If the parsed roster differs from `hive.yml.siblings`, rewrite the `siblings:` block and leave the
   file staged for §6.3. Preserve key order and all comments elsewhere in `hive.yml`.
4. **Read failure (unavailable / 401 / 403 / page moved) is not an error.** Record
   `siblings: skipped (<reason>)`, keep the on-disk roster, and continue. **NEVER block or fail
   Parliament on registry reachability** — a stale roster causes a *missed* cross-hive suggestion,
   never a wrong or classification-unsafe one (the guard keys off each sibling's recorded ceiling,
   defaulting absent ceilings to `UNCLASSIFIED`).

---

## 2. Push — Own-Row Upsert

**Skip this section entirely if `federation.register` is `false`** — this Hive has opted out of being
listed. Report `row: skipped (opted out)`. Do **not** delete an existing row (see Federation opt-outs).

Reuse the storage body already fetched in §1 — one read per run, not two. (If §1 was skipped because
`cross_hive_routing` is `false`, fetch it here instead; either way it is one read.)

1. Locate this Hive's row by `{HIVE_SLUG}` in the **Hive** cell's link text.
2. **Row absent** ⇒ build a row per §3 and insert it **alphabetically by slug** into `<tbody>`.
   Record `row: inserted`.
3. **Row present** ⇒ compare cell-by-cell against `hive.yml` for exactly these fields:
   `Apiary ver`, `Purpose / What lives here`, `Repository`, `Max Classification`, `Owners`, `Slack`.
   The **Hive** cell (slug + repo link) is rebuilt only if `{REPO}` changed.
   - **No differences** ⇒ **write nothing.** Record `row: current`. Idempotency is mandatory: dozens
     of Hives running nightly Parliaments would otherwise churn the page history with empty
     revisions, burying the real edits.
   - **Differences** ⇒ patch only the drifted cells, leaving every other Hive's row byte-identical.
     Record `row: updated (<field>: <old>→<new>, …)`.
4. Write once: `confluence update {REGISTRY_PAGE_ID} -f <edited-file> --format storage`.

**Column allow-list (exhaustive).** The Apiculturist may write **only** the seven columns in §3, and
every value is sourced from `hive.yml`. It **NEVER** writes knowledge-file content, inbox content,
source material, or any prose it authored itself.

`{HIVE_PURPOSE}` is human-authored `hive.yml` text — pass it through unchanged, but run it through
`assets/sentinel-patterns.json` first. On a Sentinel hit: skip the purpose cell, write the other
cells, and report `purpose: withheld (sentinel: <pattern>)`. The registry is a broad-audience
Confluence page and `purpose` is the one field a human could have pasted something sensitive into.

**The classification cell is metadata, never a marking.** It reports the Hive's ceiling from
`hive.yml.classification.max_level`. The Apiculturist never *changes* a ceiling, and its writes have
no bearing on the classification direction guard (`custodian-workflow.md` §2.1 step 5 / §4.1), which
keys off the sibling roster from §1 — unchanged by this spec.

---

## 3. Row Markup (canonical)

**This section is the single source of truth for registry row markup.** `references/mode-create.md`
Step 6 cites it; do not duplicate the markup there.

Column order: **Hive** (`<a href="https://ghe.meridian.example/{org}/{repo}">{slug}</a>`) ·
**Purpose / What lives here** (`{HIVE_PURPOSE}`) · **Repository** (`<code>org/repo</code>`) ·
**Max Classification** · **Owners** (`{CODEOWNERS_CSV}`) · **Slack** (`#{SLACK_CHANNEL}`) ·
**Apiary ver** (`{UPSTREAM_VERSION}`).

Build rows **by copying the markup pattern of an existing row in the page's `<tbody>`** — do not
invent cell markup; mirror what the current rows use so the table stays consistent.

**Max Classification — highlighted table cell, NOT a `status` macro.** The column shows the Hive's
*ceiling*, not a marking on any single fact. Confluence's `status` lozenge palette has no purple, and
CUI's banner color is purple by DoD convention, so use a highlighted `<td>` (the `highlight-#HEX` +
`data-highlight-colour` pattern, which survives Confluence's sanitizer where inline CSS does not),
center-aligned:

| Ceiling | Cell markup |
|---|---|
| `UNCLASSIFIED` | `<td class="highlight-#abf5d1" data-highlight-colour="#abf5d1" style="text-align: center;"><strong>UNCLASSIFIED</strong></td>` (green) |
| `CUI` | `<td class="highlight-#998dd9" data-highlight-colour="#998dd9" style="text-align: center;"><strong>CUI / ITAR</strong></td>` (purple) |
| `FOUO` (legacy only) | `<td class="highlight-#fff0b3" data-highlight-colour="#fff0b3" style="text-align: center;"><strong>FOUO (legacy)</strong></td>` (yellow) |

Hives labelled `CUI / ITAR` live in `restricted-org` and may hold CUI and ITAR-controlled content
with correct markings. `FOUO` is obsolete per DoDI 5200.48 and is never selectable for a new Hive; if
an existing row or `hive.yml` still carries it, render the yellow cell and flag it to the Hive's
codeowners to reassess against the CUI Registry. **MUST NOT** silently rewrite a `FOUO` ceiling to
`CUI` or `UNCLASSIFIED` — that is a human classification judgment, not a normalization.

`style="text-align: center;"` centers the label (cell-level `style` survives the sanitizer where
span-level styling does not). If an existing row uses a different-but-consistent pattern, prefer
matching the page over these exact hexes — the rule is "look like the rows already there."

---

## 4. Degradation & Concurrency

**Write failure (403/401, CLI missing, unauthenticated) — do NOT silently skip.** Emit the exact
rendered `<tr>` (or the specific cell diffs, for an update) into the return summary so Parliament
carries it into the run report:

> Could not write the registry automatically. Add/update this Hive at {REGISTRY_URL} manually — here
> is the row: `<tr>…</tr>`

Record `row: FAIL (manual follow-up)`. **Parliament continues and succeeds.** Registry reconciliation
is never a Parliament gate.

**Version conflict (lost update).** Confluence updates are page-version-numbered, and many Hives run
Parliament on the same nightly cron. If `confluence update` is rejected for a stale version: re-read
the page, rebuild the patch against the fresh body, retry **once**. On a second rejection, degrade per
the paragraph above rather than retrying in a loop. **NEVER force-overwrite a newer page body** — that
would silently delete another Hive's just-written row.

**Lock scope.** `.parliament-running` guards *this* Hive's repo, not the shared registry page.
Cross-Hive serialization on the page is provided solely by the retry-once-then-degrade rule above.

---

## 5. Return Format

Return **at most three lines** to Parliament. This brevity is the entire point of running as a
subagent: the registry table, the storage XML, and per-row detail all stay in the Apiculturist's
context and never enter Parliament's.

    siblings: 22 (+6 added, 0 removed)
    row: updated (Apiary ver: 2.9.3→2.11.0)
    registry: ok

Failure and edge shapes:

    siblings: skipped (confluence 403)
    row: FAIL (manual follow-up) — <tr> in run report
    registry: degraded

    siblings: 22 (no change)
    row: current
    registry: ok

    registry: not configured — run /apiary upgrade to backfill

    siblings: skipped (opted out)
    row: updated (Owners: +mherbst)
    registry: ok (cross_hive_routing off)

    registry: disabled (federation opt-out)
