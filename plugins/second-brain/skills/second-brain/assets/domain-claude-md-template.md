<!-- decay: slow -->

# {DOMAIN_NAME}

{ONE_LINE_DESCRIPTION}

## Start Here

**The agent definition is the entry point and the authority:**

```
{AGENT_FILE — e.g. financial-advisor.md}
```

Read that file and follow it. It carries the routing rules, the operating protocol bootstrap, the domain rules, and the knowledge-maintenance discipline. **This file is a signpost, not a rulebook** — it exists so that a session which lands in this directory without an agent still knows where to go.

Everything about *how to behave* lives in the agent definition, which loads the universal protocol (learning loops, contribution triage, knowledge schema) from the shared `second-brain` skill. Reading the agent file is what invocation means, so those rules cannot be missed. Rules restated here could be — this file only loads when a session's working directory happens to be here.

## Ambient Guardrails

These apply to **any** session touching this folder, including hand-editing files with no agent loaded. They are here precisely because they must hold even when the agent definition was never read.

{AMBIENT_GUARDRAILS — the short list of rules that survive without an agent. Typical entries:
- Sensitivity: "This folder contains {financial/medical/personal} PII. Never share contents outside the vault; reference external documents by path only."
- Write zones (multi-maintainer folders): "{folder-a}/ and {folder-b}/ are single-owner. Root files are additive-edit only — append, don't restructure."
- Raw-data immutability: "{data-folder}/ holds raw exports — never edit in place; corrections go in the synthesis layer."
- Never fabricate figures, account numbers, or identifiers. If you can't cite it, mark it unverified.
Keep this to 5 or fewer. Anything longer is agent behavior and belongs in the agent definition.}

## Contents

| Path | What |
|---|---|
{CONTENTS_ROWS — one row per knowledge file or subfolder, with a one-line description. If the domain keeps an index.md, one row pointing at it is enough.}

## Dependencies

Install the shared `second-brain` skill so the agent can load the current operating protocol:

> {SKILL_INSTALL_POINTER — for this marketplace: `claude plugin marketplace add ahartzog/agent-plugins` then `claude plugin install second-brain@ahartzog`}

**This is a prerequisite, not an enhancement.** The protocol exists only in the skill and is not restated anywhere in this folder. Without it the agent can answer from the knowledge files but will not write to them — the loop routing and triage rules that make contributions safe aren't loaded.

## Notes

{OPTIONAL_NOTES — orientation for a human opening this folder: where the source documents live, what the folder is for, who maintains it. Delete if not needed.}
