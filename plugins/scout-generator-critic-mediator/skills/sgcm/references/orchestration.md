# SGCM Orchestration Patterns

How to structure the stages, manage parallelism, and handle iteration.

---

## Stage Execution

### Scout Stage

**When**: `/sgcm` (full loop)

**Parallelism**: Launch multiple Explore agents if scope is large. For smaller scopes,
main agent can scout directly with tool calls.

**Sizing**: One agent per independent area. If scouting a repo with 5 top-level directories
of interest, launch 5 scouts. If scouting a single file, just use grep/read directly.

**Output feeds**: Scout Checklists become context for Generator and Critic stages.

**Key principle**: Scouts are exhaustive within scope. Better to over-collect than miss context
that generators or critics will need.

**Freshness**: Always `git fetch --all` before scouting branch or PR state. Stale local refs
cause false findings (e.g., reporting a branch as missing or diverged when it's fine on remote).
More generally, any Scout that checks mutable external state should refresh that state first.

### Generator Stage

**When**: `/sgcm:gcm` or `/sgcm`

**Parallelism**: Launch parallel agents when tasks are independent. For a 7-file documentation
refresh, launch 7 generator agents. For a single complex analysis, one agent is fine.

**Sizing**: Match the natural units of work. Do not split a single coherent task across agents --
each agent should produce a complete unit of output.

**Input**: Scout Checklists (if scout stage ran) + task specification. Include relevant ground
truth facts in each agent's prompt.

**Output feeds**: Work product for critics to verify. Generator Checklists for mediator to
cross-reference.

### Critic Stage

**When**: `/sgcm:cm`, `/sgcm:gcm`, or `/sgcm`

**Parallelism**: Launch one critic per unit of work product. If generators produced 7 files,
launch 7 critics. Critics can also be specialized by lens (like the code-review pattern):
  - Critic A: structural accuracy (do files/dirs exist?)
  - Critic B: content accuracy (are APIs/examples correct?)
  - Critic C: convention compliance (style rules, naming, etc.)

**Sizing**: 8-15 checks per critic is a good range. Fewer than 5 means the critic is too narrow.
More than 20 means the scope should be split.

**Input**: The work product + Scout Checklists (ground truth to verify against). Include
specific verification commands in the critic's prompt when possible.

**Output feeds**: Critic Checklists for mediator. VERIFY_CMDs for spot-checking.

### Mediator Stage

**When**: Always (M is required in every invocation)

**Parallelism**: None -- mediator is always the main agent. This is intentional: the mediator
needs full context of all findings to make coherent triage decisions.

**Process**:
1. Read all checklists from prior stages
2. Filter by confidence threshold (>= 75 for critic, >= 60 for generator)
3. Run VERIFY_CMDs for high-severity findings
4. Cross-reference generator insights against critic verifications
5. Apply fixes
6. Decide whether to re-critic (Tier R)

### Prompt Interpolation Safety (any stage that injects upstream findings)

When a stage builds a downstream agent's prompt by interpolating upstream findings into a string template, a mis-escaped or unresolved variable is a **silent** failure: a broken `${var}` renders as the literal text `${var}` (or empty), so the critic/verifier runs happily against **no findings** and reports everything clean. Nothing errors; the verification stage is quietly blinded and its green result is meaningless.

Two defenses, use both:
- **Enumerate, don't just inject.** A verify/critic prompt must list the specific claims to check as explicit prose, not rely solely on interpolated upstream text. If the injection fails, the agent still has a concrete work-list.
- **Assert non-empty before dispatch.** Before launching a downstream agent, confirm the interpolated findings block is non-empty and well-formed. An empty findings set should short-circuit to "nothing to verify," never dispatch a verifier that will rubber-stamp silence.

*(Worked example: a mis-escaped `${var}` in a verifier prompt fed the verifier no findings; it reported all-clear and the blindness was invisible until the orchestration script was re-read.)*

---

## Batching Strategy

For large tasks, batch the stages rather than running everything at once.

### Round-Based Batching

Split work into rounds based on dependencies:

```
Round 1 (parallel): Independent tasks A, B
  Scout A + B -> Generate A + B -> Critic A + B -> Mediate A + B

Round 2 (parallel): Tasks C, D, E that don't depend on Round 1
  Scout C + D + E -> Generate C + D + E -> Critic C + D + E -> Mediate C + D + E

Round 3 (sequential): Task F that depends on Round 1 + 2 outputs
  Scout F -> Generate F -> Critic F -> Mediate F
```

### Agent Count Guidelines

| Task scope | Scout agents | Generator agents | Critic agents |
|------------|-------------|-----------------|---------------|
| 1-2 files | 0 (main agent) | 1-2 | 1-2 |
| 3-7 files | 1-3 | Match file count | Match file count |
| 8+ files | 3-5 (by area) | Batch into rounds | Match generators |

Keep total parallel agents under 8 to avoid context/resource pressure.

---

## Re-Critic Rounds (Tier R)

After mediator applies fixes, optionally re-run the critic stage to verify the fixes.

**When to re-critic:**
- Any HIGH severity finding was fixed (verify the fix is correct)
- Mediator made structural changes (new content, removed sections)
- Multiple interrelated fixes (changes might conflict)

**When to skip re-critic:**
- Only LOW severity cosmetic fixes
- Single isolated change with obvious correctness
- Time pressure outweighs verification value

**Re-critic scope**: Only the specific areas that were fixed, not the entire work product.
Launch targeted critics with narrow scope.

---

## Composing with Specific Skills

### SGCM + executing-plans

The most common composition. The plan defines tasks; SGCM orchestrates their execution.

```
/sgcm:gcm + /executing-plans

Round 1: Generator agents execute plan tasks in parallel batches
Round 2: Critic agents verify each task's output
Round 3: Mediator triages findings, applies fixes
Optional: Re-critic on fixed areas
```

### SGCM + code-review

Code review already has a multi-agent structure. SGCM adds the generator role.

```
/sgcm:gcm + /code-review

Scout: Catalog PR changes, CLAUDE.md files, modified file history
Generator: Identify patterns, implications, suggestions beyond bugs
Critic: Standard code-review agents (bugs, history, CLAUDE.md compliance, etc.)
Mediator: Synthesize, score, filter, produce final review
```

### SGCM + brainstorming

SGCM can structure the exploration phase of brainstorming.

```
/sgcm + /brainstorming

Scout: Catalog existing codebase patterns, prior art, constraints
Generator: Propose approaches, find analogies, explore implications
Critic: Stress-test each approach against constraints and edge cases
Mediator: Synthesize into final design recommendation
```

---

## Worked Example: Helm Chart Drift Audit

A Kubernetes cluster where Helm chart values, deployment manifests, and running pod configs
have drifted from each other. Three sources of "truth" that should agree but don't.

### Scout Stage (3 parallel agents)

**Scout A**: Catalog Helm chart values
```
FACT: values.yaml sets replica count to 3 for api-gateway
EVIDENCE: grep "replicaCount" charts/api-gateway/values.yaml
RESULT: replicaCount: 3
```

**Scout B**: Catalog deployment manifests
```
FACT: deployment.yaml sets replicas to 5 for api-gateway
EVIDENCE: grep "replicas" k8s/deployments/api-gateway.yaml
RESULT: replicas: 5
```

**Scout C**: Catalog running pod state
```
FACT: api-gateway has 5 running pods
EVIDENCE: kubectl get pods -l app=api-gateway --no-headers | wc -l
RESULT: 5
```

### Generator Stage (1 agent, fed all scout output)

```
INSIGHT: api-gateway has Helm->manifest drift (3 vs 5 replicas)
IMPLICATION: Someone manually edited the manifest without updating Helm values.
  This pattern likely exists in other services too.
SCOPE: All services in k8s/deployments/ vs charts/
CONFIDENCE: 85 (confident -- direct numeric mismatch)

INSIGHT: manifest matches running state (both 5), suggesting manual edit was intentional
IMPLICATION: Helm values are stale, not the deployment. Fix should update values.yaml, not revert deployment.
SCOPE: charts/api-gateway/values.yaml
CONFIDENCE: 70 (probable -- could also be an autoscaler, need to check HPA)
```

### Critic Stage (2 agents)

**Critic A**: Structural verification
```
CHECK 1: PASS - api-gateway values.yaml exists at stated path
CHECK 2: PASS - deployment.yaml exists at stated path
CHECK 3: FAIL - Generator claims "pattern likely exists in other services" but
  only api-gateway was checked
CONFIDENCE: 80
SEVERITY: MEDIUM
VERIFY_CMD: diff <(grep -r "replicaCount" charts/*/values.yaml) <(grep -r "replicas:" k8s/deployments/)
```

**Critic B**: Causal verification
```
CHECK 4: FAIL - Generator assumes no HPA but did not check
CONFIDENCE: 75
SEVERITY: HIGH (fix direction depends on whether HPA exists)
VERIFY_CMD: kubectl get hpa -l app=api-gateway 2>/dev/null
```

### Mediator

Runs VERIFY_CMDs:
- CHECK 3 VERIFY_CMD reveals 2 more services with drift (confirmed, generator was right about pattern)
- CHECK 4 VERIFY_CMD shows no HPA exists (generator assumption was correct, but should have been verified)

Final action: Update 3 Helm value files, document the drift pattern, add CI check for future drift.
