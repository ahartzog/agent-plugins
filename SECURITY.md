# Security Policy

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private vulnerability reporting:
[Report a vulnerability](https://github.com/ahartzog/agent-plugins/security/advisories/new).
It is private between you and the maintainer until a fix ships.

Expect an acknowledgement within a week. This is a personal project maintained by one
person, not a funded product — there is no on-call rotation and no formal SLA beyond
that best effort.

## What is in scope

These plugins ship shell and Python that Claude Code executes on the user's machine,
with the user's permissions:

- `plugins/apiary/skills/apiary/assets/generate-hook.sh`
- `plugins/second-brain/skills/second-brain/assets/pre-push-sentinel.sh`
- `plugins/second-brain/skills/second-brain/scripts/extract_session.py`

Anything that lets a repository, a knowledge file, or an inbox document cause code to
run, escape its intended path, or exfiltrate data is in scope. Concretely:

- Command or argument injection through filenames, frontmatter, or document content
- Path traversal that writes outside the intended Hive or vault directory
- A generated git hook that can be made to execute attacker-controlled input
- Prompt injection in knowledge files that steers an agent into destructive tool use
- **Sentinel bypasses** — a real credential that the pre-push
  scanner fails to catch. The scanner is a safety net users rely on; a silent miss is a
  vulnerability, not a feature request.

## What is not in scope

- Synthetic credentials in `plugins/apiary/skills/apiary/tests/`. Those files exist to
  exercise Sentinel's detection patterns. Every value in them is fabricated — the AWS
  key is Amazon's published documentation example, and the RSA block is truncated and
  non-functional. They are excluded in `.gitguardian.yaml`.
- Prompt injection that requires the user to have already granted the agent permissions
  it asked for. These plugins operate inside Claude Code's permission model; they do not
  replace it.
- Findings against a Hive or vault you control, where you are the only one who could
  have supplied the malicious input.

## Verifying what you install

Plugins auto-update from `main`. If you want to know what you are running:

- `main` is protected — no force pushes, no deletion, and changes land through pull
  requests.
- Every plugin change ships a `CHANGELOG.md` entry and a `version` bump in that
  plugin's `.claude-plugin/plugin.json` (see [CONTRIBUTING.md](CONTRIBUTING.md)), so a
  behavior change you did not expect should always be traceable to a released version.
- Pin to a tag rather than tracking `main` if you would rather review changes before
  they reach your machine.
