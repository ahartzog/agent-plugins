# {HIVE_NAME} Hive Mind

This repository is a collectively-maintained AI knowledge base for {SCOPE_SENTENCE}.

**When working in this repo, invoke `/{HIVE_SLUG}` first.** The skill loads the persona, delegates to the Apiary for protocol, and routes to the correct workflow.

## The One Rule You Must Know

**NEVER edit `knowledge/` files directly.** All contributions go through the inbox:

1. Write to `_inbox/YYYY-MM-DD-<author>-<topic>.md` with `status: ready` in frontmatter
2. Tag entries per the contribution categories (`[link]`, `[architecture]`, `[status]`, etc.)
3. Commit and push the inbox file

Parliament processes inbox files into knowledge files via PR. Direct edits to `knowledge/` bypass triage and will be reverted.

## Quick Reference

- Hive skill: `/{HIVE_SLUG}`
- Upstream protocol: `/apiary` (Hive Parent Protocol)
- Identity: `hive.yml`
- Persona: `PROTOCOL/agent-definition.md`
- Hive registry (all Hives): [{REGISTRY_URL}]({REGISTRY_URL})

## Classification / Security

{CLASSIFICATION_SECTION}

<!--
  Create mode substitutes {CLASSIFICATION_SECTION} with one of:

  UNCLASSIFIED Hive (default):
    "- **No CUI or classified content in this repo.** Classified material is
       referenced by storage-system path only. Four layers enforce this:
       pre-push Sentinel hook (classification-banner scan), session agent,
       GHE pre-receive hook (server-side, optional), Parliament intake scan.
       See the Apiary `PROTOCOL/security-policy.md`."

  Classified Hive (max_level: CUI, marking_required: true):
    "- **This Hive is authorized for content up to {MAX_LEVEL}.** Every knowledge
       and inbox file must carry a `classification:` field in frontmatter. Files
       containing classified content must also carry a matching banner
       (e.g. `CUI`) as the first line of the body.
     - **Unmarked classified content will be quarantined by Parliament.**
     - **Content above {MAX_LEVEL} is prohibited.** Anything SECRET or above, or
       any compartmented material (SCI, SAP), does not belong here — route to the
       appropriate classified enclave instead.
     - Storage tier: {STORAGE_TIER}. The operator is responsible for ensuring
       the repo is hosted accordingly."
-->

