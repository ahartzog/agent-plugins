# SGCM - Scout-Generator-Critic-Mediator

A composable multi-agent orchestration pattern for Claude Code. Layer structured verification
rounds onto any task by invoking SGCM alongside other skills.

## The Four Roles

- **Scout** -- Faithful reporter. Catalogs reality with direct evidence. "What IS?"
- **Generator** -- Divergent explorer. "Yes, and..." Finds patterns, implications, connections. "What does this IMPLY?"
- **Critic** -- Convergent verifier. Adversarial, demands proof. "What's WRONG?"
- **Mediator** -- Journal editor. Spot-checks both sides, triages, makes final calls. "What do we DO?"

## Invocation

Right-substring of SGCM that includes M:

| Invocation | Stages | Use When |
|-----------|--------|----------|
| `/sgcm:m` | Mediator only | Triage existing findings |
| `/sgcm:cm` | Critic + Mediator | Verify existing work |
| `/sgcm:gcm` | Generator + Critic + Mediator | Produce and verify |
| `/sgcm` | All four stages | Full discovery loop |

Cannot skip stages. Must include Mediator. Prepend only in order.

## Key Features

- Structured checklist communication protocol (not prose)
- Confidence scoring (10-100 scale) with threshold filtering
- Parallel subagent execution per stage
- Composable with any other skill

## References

- `skills/sgcm/references/role-prompts.md` -- Subagent prompt templates
- `skills/sgcm/references/checklists.md` -- Output formats and scoring rubric
- `skills/sgcm/references/orchestration.md` -- Batching, parallelism, worked example

## License

MIT © 2026 Alek Hartzog — see [LICENSE](LICENSE). Use it, fork it, build on it; please keep the attribution.
