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

## Security

- **No credentials or PII in this repo.** Every push is scanned by the Apiary's
  built-in Sentinel hook — this applies unconditionally and cannot be disabled.
- **Sensitivity marking, if this Hive needs one** (PHI, PCI, trade-secret, or a
  bespoke public/internal/confidential ladder), is enforced by a Hive-declared
  gate extension layered on top of the built-in scan — see the Apiary
  `references/authoring-gate-extensions.md`.

See the Apiary `PROTOCOL/security-policy.md` for the full model.

