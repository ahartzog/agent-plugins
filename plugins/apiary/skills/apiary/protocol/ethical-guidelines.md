---
layer: PROTOCOL
type: ethical-guidelines
description: "Agent behavioral boundaries, PII handling, and attribution standards — DRAFT pending working session with CODEOWNERS"
last_updated: 2026-04-16
status: DRAFT — INCOMPLETE
codeowners: (read from hive.yml)
---

# Ethical Guidelines

> **STATUS: DRAFT — INCOMPLETE**
>
> This file requires a working session with a CODEOWNER to adapt the ethical framework to the multi-user Hive Mind context. The structure below is a placeholder. Do not treat this as authoritative until the status field is updated and a CODEOWNER PR has been merged.
>

---

## 1. Agent Behavioral Boundaries

_To be defined with CODEOWNERS._

Placeholder topics:
- What the agent is permitted to assert vs. what it must present as uncertain
- How the agent handles conflicting instructions from different users
- When the agent must escalate to a human rather than synthesizing an answer
- Boundaries on the agent's role in strategic or prioritization decisions
- How the agent handles requests that conflict with PROTOCOL

---

## 2. PII Handling Rules

These rules are currently defined in `PROTOCOL/security-policy.md` (PII section) and `PROTOCOL/agent-definition.md` (PII rules). Ethical guidelines will provide the principles behind those rules.

Placeholder topics:
- Why professional attribution is the correct scope (not personal information)
- The distinction between public professional information and private personal information
- How the agent should respond when a user inadvertently shares personal information
- Retention: what the system stores vs. what is ephemeral

Current operative rules (pending ethical framework):
- Record professional attribution only: name, role, team, professional contact
- Never record: personal addresses, personal phones, personal opinions about individuals, personal attacks

---

## 3. Content That Must Never Be Recorded

The following content categories must not be written to the inbox, knowledge base, or any repository file:

- Personal attacks on any individual
- Personal opinions about individuals (as distinct from professional assessments of work or decisions)
- Content intended to embarrass, harm, or target a person
- Speculation about individuals' personal motivations or character

These restrictions apply regardless of the contributor's intent. If a user submits content in these categories, the agent must decline to record it and explain why.

_Ethical framework for these restrictions — and the agent's behavior when users push back — to be defined with CODEOWNERS._

---

## 4. Attribution Standards

Attribution serves two purposes:
1. **Accountability:** Every fact in the knowledge base is traceable to a contributor. Contributors stand behind what they submit.
2. **Trust calibration:** Over time, the system may weight contributions by historical accuracy. Attribution makes this possible.

Attribution standards:
- Inbox files are attributed by GHE username (enforced by the push mechanism)
- Contributions within inbox files carry the author's identity from the file header
- The attribution chain is preserved through Parliament processing and into the knowledge base

_Additional guidance on attribution in disputed or sensitive contributions — to be defined with CODEOWNERS._

---

## 5. Decisions That Require Human Judgment

_To be defined with CODEOWNERS._

Placeholder topics:
- Categories of decisions the Parliament must escalate rather than resolve autonomously
- How the agent signals uncertainty vs. known ignorance vs. refusal
- The threshold for "this needs a human" in strategic or sensitive topics
- How the agent handles requests that are technically answerable but ethically ambiguous

---

## Contributing to This File

Changes to this file require:
1. A working session with a CODEOWNER designated as ethical guidance lead for this Hive
2. CODEOWNER PR approval
3. Update of `status` field from DRAFT to APPROVED

This file must not be merged as final without a CODEOWNER's explicit sign-off.
