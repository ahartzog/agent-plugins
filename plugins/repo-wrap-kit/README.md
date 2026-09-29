# repo-wrap-kit

A portable skill, `design-repo-wrap`, that builds a session-close skill (a **wrap**) for
whichever repository you run it in. The wrap closes a session's loose ends and routes what
the session learned into the places the next session loads at startup. Each repo tracks
work, keeps knowledge and integrates changes its own way, so the kit designs each wrap from
a survey of the repo rather than shipping one fixed checklist.

## The idea

Each session learns things: a pitfall, a command that works, a doc that was wrong, a rule
the owner corrected. That learning is gone once the session ends unless it's written
somewhere the next session loads without being asked. The wrap does that routing at the
end of every session, lands or parks the work, cleans up what the session created, and
fixes the instructions the session found wrong. Each session starts from a slightly better
repo than the one before.

```
session works ──► wrap routes learnings ──► instructions, docs, tracker, memory
      ▲                                              │
      └────────── next session loads them at startup ┘
```

## What's here

```
plugins/repo-wrap-kit/
├── README.md                        this file
├── CHANGELOG.md
├── .claude-plugin/plugin.json
└── skills/design-repo-wrap/         the skill
    ├── SKILL.md                     seven steps: survey → ask → design → write → install → verify → land
    ├── references/
    │   ├── discovery.md             survey table and where to look for each dimension
    │   ├── learning-loop.md         startup paths, routing table, retro questions, harvest input
    │   ├── wrap-anatomy.md          the seven wrap phases, their order, landing styles and hazards
    │   └── making-it-callable.md    per-agent skill folders, symlink setup, instruction lines, probes
    ├── templates/
    │   └── repo-wrap-SKILL.md       the wrap skeleton the design fills in
    └── examples/
        └── stickwars-repo-wrap.md   a finished wrap, mapped to the anatomy
```

## Use it

Install once from the `ahartzog` marketplace:

```bash
claude plugin marketplace add ahartzog/agent-plugins   # first time only
claude plugin install repo-wrap-kit@ahartzog            # Claude Code
codex plugin add repo-wrap-kit@ahartzog                 # Codex
```

Then, from a repo's root, run `/repo-wrap-kit:design-repo-wrap` in Claude Code, or
`$design-repo-wrap` in Codex. It surveys the repo and asks you four questions: authority,
homes for learnings, which agents, and what's off-limits. Then it writes the wrap into the
repo, wires it up for each agent, verifies it, and lands the change. From then on the repo's
own command is `/repo-wrap`, and it travels with the repo: collaborators don't need this plugin.

**Proposal only.** Ask for "design-repo-wrap, proposal only". It surveys read-only, takes
its recommended defaults, and writes the survey, decisions, routing table and draft wrap to
a folder outside the repo for you to review.

## Where it came from

The StickWars VR `repo-wrap` (PR #303, 2026-09-27): a plan review, two adversarial review
rounds, and three later fixes from sessions that used it; the hazards in
`references/wrap-anatomy.md` are what those rounds found. Proposal-mode test runs on two
other repos (2026-09-29), one with no tracker and no remote, shaped the landing styles,
hazard triggers and proposal outputs. Agent skill-folder facts in
`references/making-it-callable.md` were checked against vendor docs on 2026-09-29.
