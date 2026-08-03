# SGCM Checklist Formats and Scoring

The Checklist Manifesto principle: experts fail from ineptitude (skipping steps), not ignorance
(not knowing). Free-form prose lets you skip things implicitly. A checklist makes every claim
explicit and verifiable.

Each SGCM role produces a structured checklist, not prose. This is the communication protocol
between roles.

---

## Scout Checklist Format

Facts only. No opinions. Each entry is one verifiable observation.

```
FACT: src/services/ contains 5 subdirectories
EVIDENCE: ls src/services/
RESULT: auth/ notifications/ payments/ reporting/ users/

FACT: UserService source files use User prefix
EVIDENCE: ls src/services/user/
RESULT: UserService.ts UserService.test.ts UserRepository.ts UserMapper.ts ...

FACT: src/services/notification/ exists but is empty
EVIDENCE: ls -la src/services/notification/
RESULT: total 8 (only . and ..)
```

**Rules:**
- One FACT per observation
- EVIDENCE must be an exact tool call or command
- RESULT must be the actual output (truncate if very long, but note truncation)
- Never infer -- if you did not run a command, do not report a fact

---

## Generator Checklist Format

Insights with implications and honest confidence scoring.

```
INSIGHT: The retry logic in HTTPRetryClient matches WebSocketRetryClient
IMPLICATION: A shared retry abstraction could reduce duplication across clients
SCOPE: src/clients/ (HTTP, WebSocket); possibly src/legacy/ (SOAP, FTP)
CONFIDENCE: 60 (probable -- verified in 2 clients, unverified in 2 others)

INSIGHT: The base.config.ts / config.ts naming convention implies frozen vs override layering
IMPLICATION: Any new service config file should follow this convention
SCOPE: src/config/ (all ~40 files)
CONFIDENCE: 85 (confident -- consistent across 15+ checked pairs)

INSIGHT: Shared middleware patterns appear in both the payments and auth services
IMPLICATION: A common middleware layer could reduce duplication across microservices and simplify future onboarding
SCOPE: src/services/payments/ src/services/auth/
CONFIDENCE: 40 (speculative -- service architectures may differ intentionally)
```

**Rules:**
- One INSIGHT per observation or production
- IMPLICATION describes what this means or where else it applies
- SCOPE names specific files/directories affected
- CONFIDENCE uses the 10-100 scale (see rubric below)
- Distinguish speculative (<50) from probable (50-70) from confident (>70)

---

## Critic Checklist Format

Adversarial verification with confidence scoring and mediator verification commands.

```
CHECK 1: PASS
CLAIM: "config/ contains ~40 flat config files"
EVIDENCE: find src/config/ -maxdepth 1 -name "*.config.ts" | wc -l -> 42
CONFIDENCE: 95
SEVERITY: LOW (count is approximate, 42 rounds to ~40)
VERIFY_CMD: find src/config/ -maxdepth 1 -name "*.config.ts" | wc -l

CHECK 2: FAIL
CLAIM: "src/services/config/ exists with ConfigDefaults.ts"
EVIDENCE: ls src/services/config/ -> No such file or directory
CONFIDENCE: 98
SEVERITY: HIGH (entire doc section references nonexistent directory)
VERIFY_CMD: ls src/services/config/ 2>/dev/null

CHECK 3: UNVERIFIABLE
CLAIM: "Performance target of 2000 requests at 0.5Hz"
EVIDENCE: No benchmark tests exist on dev branch to verify
CONFIDENCE: N/A
SEVERITY: LOW (aspirational target, not a factual claim)
VERIFY_CMD: N/A

SUMMARY: 8/10 checks passed. Issues: [CHECK 2 (HIGH), CHECK 7 (MEDIUM)]
```

**Rules:**
- One CHECK per claim verified
- Status is PASS, FAIL, or UNVERIFIABLE
- CLAIM quotes the exact text being tested
- EVIDENCE shows the command and its output
- CONFIDENCE uses the 10-100 scale
- SEVERITY indicates impact (HIGH = wrong content, MEDIUM = misleading, LOW = imprecise)
- VERIFY_CMD is a single command the mediator can copy-paste to spot-check
- End with SUMMARY showing pass rate and listing failures by severity

---

## Confidence Scoring Rubric (10-100)

Adapted from the code-review confidence scale. Apply to both Generator insights and Critic findings.

| Score | Label | Meaning |
|-------|-------|---------|
| 10 | Definitely wrong | Does not stand up to any scrutiny |
| 20 | Almost certainly wrong | Very unlikely to be real |
| 30 | Probably wrong | More likely wrong than right |
| 40 | Leaning wrong | Uncertain, slightly more likely wrong |
| 50 | Uncertain | Could go either way; insufficient evidence |
| 60 | Leaning real | Slightly more likely real than not |
| 70 | Probably real | More likely real, but not fully verified |
| 80 | Highly confident | Verified, very likely real and impactful |
| 90 | Very highly confident | Double-checked with strong evidence |
| 100 | Absolutely certain | Confirmed with direct, unambiguous proof |

### Threshold Guidance

| Consumer | Threshold | Rationale |
|----------|-----------|-----------|
| **Mediator acting on Critic findings** | >= 75 | High bar -- only fix what is clearly wrong |
| **Mediator considering Generator insights** | >= 60 | Lower bar -- worth investigating further |
| **Critic reporting to Mediator** | Report all >= 30 | Let mediator decide; filter out only obvious noise |
| **Re-critic round trigger** | Any HIGH severity fix | After mediator applies fixes, re-verify the specific areas |

---

## False Positive Guidance

For critics: these are likely false positives, score them LOW:

- Pre-existing issues not introduced by the current work
- Pedantic style nits that do not affect correctness
- Aspirational or approximate claims (e.g., "~100 files" when actual is 103)
- Claims that are technically imprecise but not misleading
- Issues a linter or build system would catch independently

For critics: these are likely real, score them HIGH:

- Fabricated file/directory names that do not exist
- Wrong structural claims (e.g., "nested subdirectories" when reality is flat)
- Incorrect API examples that would cause errors if followed
- Missing content that creates gaps in understanding
- Contradictions between different sections of the same document

---

## Mediator Verification Protocol

The mediator uses a DO-CONFIRM checklist pattern (Checklist Manifesto):
critics already did the work, mediator confirms the key findings.

1. **Collect** all Critic Checklists
2. **Filter** findings >= 75 confidence AND HIGH/MEDIUM severity
3. **Spot-check** by running VERIFY_CMD for filtered findings
4. **Cross-reference** Generator insights against Critic verifications
5. **Triage** into: confirmed fix, false positive, needs-more-investigation
6. **Apply** fixes for confirmed issues
7. **Re-critic** (Tier R) if any HIGH severity fixes were applied

Present results as:

```
| # | Finding | Source | Confidence | Verified? | Action |
|---|---------|--------|------------|-----------|--------|
| 1 | services/config/ does not exist | Critic #2 | 98 | Yes (ls confirmed) | Removed section |
| 2 | Retry pattern in 3 clients | Generator #1 | 60 | Partial (2/3 confirmed) | Fixed 2, skipped 3rd |
| 3 | File count ~40 vs 42 | Critic #1 | 95 | Yes | Updated to ~40 |
```
