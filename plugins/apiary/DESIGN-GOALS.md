# Apiary — Design Goals

## What This Is

The Apiary skill implements the Hive Parent Protocol (HPP) — the upstream infrastructure for managing Hive Mind knowledge bases. Each child Hive is a domain-specific repo with content; the Apiary provides the governance, pipeline, and operational protocol.

## Design Principles

1. **Protocols live upstream.** Child Hives don't copy protocol files. The Apiary loads them at runtime. This means one improvement benefits all Hives.

2. **Child repos are thin.** A Hive holds: `hive.yml` (identity), `agent-definition.md` (persona), `knowledge/` (content), `_inbox/` (contributions), and optionally `PROTOCOL/extensions/`. Nothing else.

3. **Extensions are additive only.** Child Hives can add workflows, schema fields, and triage categories. They cannot remove or replace upstream behavior.

4. **Sentinel is non-negotiable.** Every Hive gets PII/credential scanning. It cannot be disabled. A Hive that needs a sensitivity taxonomy on top of that declares it as an additive gate extension (Goal 3).

5. **Upgrades are invisible.** Protocol improvements take effect on next `operate` invocation. Breaking changes (hive.yml schema) are auto-migrated where possible. Zero-friction.

6. **hive.yml is the single source of identity.** Codeowners, slack channel, extensions, auto-merge intent — all in one file. No more hardcoded values in prose.

7. **The thin router stays thin.** SKILL.md detects mode and dispatches to `references/mode-*.md`. It must stay under 150 lines. New modes = new reference files, not a bigger router.

8. **Versioning is semver.** Major = breaking change to hive.yml/config schema. Minor = new capability. Patch = prose refinement.

9. **Zero runtime dependencies for contributors.** The Apiary must not require non-engineers to install CLIs, runtimes, or tools beyond what git provides (bash, grep, git itself). Dependencies used at generation/install time by Claude are fine (e.g., jq in the hook generator). Optional integrations chosen by the Hive (e.g., jira-cli, slack-cli) are the Hive's responsibility — those are opt-in connectors, not Apiary core.

10. **Operating instructions carry no state and no history.** A `protocol/` or `references/` file tells an agent what to do *now*. It must not carry measurements ("fast-path share is currently 11%"), narratives about how the protocol used to work, or explanations of a past defect. Those decay into lies the moment reality moves, and an agent that reads them cannot tell a live instruction from a stale anecdote. Rationale belongs in `references/*-design.md`; lessons learned belong in this file. Write the rule, not the story behind it.

## Lessons Learned

Durable lessons from building and auditing the Apiary. Recorded here so they inform the next
change without polluting the operating instructions (principle 10).

- **Capture and findability are one obligation.** Loop B (Discovery) originally ended at "knowledge base
  grows," which let files land with nothing routing to them. An unreachable file is worse than a
  missing one: "no information" reads as *the Hive has nothing on this*. Any new content surface
  must name its index and its write path in the same change that introduces it (Goal 9).
- **A restated rule will drift from its source.** Loop C (Calibration) was defined canonically as approval-ratio
  tuning and restated in two runtime surfaces as "custodian checklist growth" — an inherited
  framing that was never implemented. Restatements are a duplication class the size budgets do not
  catch. Prefer a pointer to the canonical file; if a summary is unavoidable, keep it to one line
  and say which file governs.
- **Define a thing once, or it will exist in three incompatible versions.** The routing protocol
  was copied into each Hive's persona at create time and never updated, producing 3-step, 6-step,
  and 7-step variants in production — one of which had a fallback the canonical version lacked.
  Protocol that ships by copy is protocol that forks. Mechanics live upstream; only domain content
  belongs in the child.
- **A checker that can silently pass is worse than no checker.** A coverage matcher that treats an
  empty path prefix as valid marks the entire corpus covered and reports zero orphans — a failure
  indistinguishable from success. When writing a validation rule, ask what input makes it report
  "all clear" without checking anything, and guard that input explicitly.
- **Prose cross-references have no machine check, so they rot.** Step numbers, `§` headings, and
  relative paths drift as files are reorganized; this repo accumulated dozens of dangling refs,
  including in a PR whose stated purpose was fixing dangling refs. Verify every reference you write
  against its target, and prefer a section name over a step number — names survive renumbering.
- **Fix the instrument before the thing it measures.** Changing a policy whose feedback loop is
  broken is guesswork. Repair the telemetry, take a baseline, then change the policy.
- **An index layer owes a retrieval mechanism.** "Reference, don't duplicate" is only half a design.
  Choosing not to hold canonical content is choosing to reach it, so indexing and retrieval ship
  together or the Hive answers "no information" about material it demonstrably knows the location
  of. When a rule removes content from the system, ask what now has to work for the pointer to be
  worth more than the copy.
- **A convention in use is a specification not yet written.** Catalogs were declaring store roots in
  frontmatter and writing rows relative to them long before anything resolved them; the field had
  settled on a shape while the protocol was silent. Look at what child Hives already emit before
  designing a mechanism — formalizing an existing shape costs one paragraph and no migration, while
  inventing a competing one strands every file that used the old shape.
- **A regex that errors is a scanner that silently allows.** Two Sentinel patterns shipped broken
  for months — `\s` inside a POSIX bracket expression is a literal backslash, and `[_\-.]` parses
  as a decreasing range that makes grep error — and both failures were invisible because the scan
  wrapped grep in `2>/dev/null` and no pattern had a positive detection test. Security patterns
  get a positive test each, and swallowed stderr on a security path is itself a bug.
- **Sort steps by what they dispatch on, not by when they happen.** A step list that mixes two
  dimensions reads as mutually exclusive and silently forbids valid combinations — a flat
  load-the-file list could express "grep a local catalog" and "load a section" but not "grep a
  remote catalog." When a list of cases resists a new entry, check whether it is actually two lists.

## Templates

- Placeholders use `{SCREAMING_SNAKE}` convention — grep-able and obviously not real content.
- Templates live in `skills/apiary/assets/`. Protocol files live in `skills/apiary/protocol/`.
- Changes to templates should not break Hives created by earlier versions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. Key rules:

- **Every mechanical change must pass the three canonical scenario tests** before PR.
- Run `bash skills/apiary/tests/clone-flow.test.sh` — all tests must pass.
- Protocol changes go through PR review on claude-clams.
- Prefer improving the upstream Apiary over local workarounds in child Hives.
