# Efficiency & Anti-Overengineering Audit — prompt (§33–§50)

> Disimpan verbatim dari prompt user 2026-09-05. Bagian §1–§32 tidak pernah di-commit ke repo (dicek: tidak ada di research/ maupun docs/). Hasil auditnya: `research/2026-09-05-efficiency-antioverengineering-audit.md`.

---

# 33. Efficiency & Anti-Overengineering Audit

IMPORTANT:

Do NOT assume that more structure, more skills, more validation, or more automation is automatically better.

The current Mega-SDD may already be sufficiently effective.

Your job is to determine:

> **Is the current Mega-SDD already efficient and on-point, and if not, what is the smallest set of changes that materially improves it?**

The objective is NOT to maximize features.

The objective is:

**Maximum useful output quality with minimum complexity, token usage, execution time, and maintenance cost.**

---

# 34. Audit the Current Mega-SDD Before Proposing Changes

Before proposing any new skill, workflow, schema, validator, agent, or abstraction:

Understand what the current Mega-SDD already does.

For every existing capability, determine:

- What problem does it solve?
- How often is it actually needed?
- What is its input?
- What is its output?
- How much complexity does it introduce?
- Does it materially improve PRD quality?
- Does it duplicate another capability?
- Can the same result be achieved more simply?
- Does it increase token consumption?
- Does it increase execution time?
- Does it increase maintenance burden?

Classify each capability:

```text
KEEP
SIMPLIFY
MERGE
DEPRECATE
REPLACE
UNKNOWN
```

Do not create a replacement merely because a newer architecture looks cleaner.

---

# 35. Measure Improvement vs Cost

Every proposed Mega-SDD improvement MUST be evaluated using:

```text
Value
Complexity
Token Cost
Execution Time
Maintenance Cost
Reliability Impact
```

Use a simple decision matrix:

| Improvement | Expected Value | Complexity | Token Cost | Time Cost | Maintenance | Decision |
|---|---:|---:|---:|---:|---:|---|
| Feature A | HIGH | LOW | LOW | LOW | LOW | IMPLEMENT |
| Feature B | MEDIUM | HIGH | HIGH | HIGH | HIGH | REJECT |
| Feature C | HIGH | MEDIUM | LOW | LOW | MEDIUM | CONSIDER |

Avoid building features whose marginal value is smaller than their operational cost.

---

# 36. Minimum Effective Complexity Principle

Follow this principle:

> **Use the simplest architecture that reliably solves the actual problem.**

Do NOT introduce:

- unnecessary abstractions
- unnecessary agents
- unnecessary sub-skills
- unnecessary validation layers
- unnecessary schemas
- unnecessary metadata
- unnecessary orchestration
- unnecessary graph databases
- unnecessary pipelines
- unnecessary recursive analysis
- unnecessary multi-agent workflows
- unnecessary LLM calls

unless the audit demonstrates a real problem that requires them.

---

# 37. Avoid "Enterprise Architecture for the Sake of Architecture"

Do not transform Mega-SDD into an overly complex framework simply because the project is enterprise-level.

Enterprise quality does NOT mean:

```text
More layers
More agents
More schemas
More files
More prompts
More validation
More orchestration
```

Enterprise quality means:

```text
Correctness
Consistency
Traceability
Predictability
Maintainability
Operational efficiency
```

Prefer simple mechanisms when they provide equivalent results.

---

# 38. Token Efficiency Is a First-Class Requirement

Mega-SDD is an AI-driven system.

Therefore token consumption is an engineering constraint.

For every proposed skill or workflow, consider:

### Input Token Cost

How much context must be provided?

### Processing Token Cost

How much reasoning/output is required?

### Repeated Token Cost

Does the same context get sent repeatedly?

### Retrieval Cost

Does the system load more information than necessary?

### Output Cost

Does the skill generate excessive documentation?

### Reprocessing Cost

Does a small change require re-running expensive analysis?

Prefer:

```text
Targeted retrieval
Incremental processing
Context reuse
Small focused skills
Deterministic preprocessing
Structured outputs
```

over repeatedly sending the entire project context to an LLM.

---

# 39. Time-to-Delivery Is a First-Class Requirement

Do NOT sacrifice development velocity for theoretical architectural perfection.

When evaluating improvements, ask:

> "Will this make Mega-SDD meaningfully better in practice, or will it mostly make the architecture more sophisticated?"

Prefer improvements that:

- reduce manual work
- reduce re-analysis
- reduce ambiguity
- reduce hallucination
- improve retrieval
- improve implementation accuracy
- shorten future development cycles

Avoid improvements that primarily:

- make diagrams prettier
- create additional abstractions
- add metadata nobody uses
- create infrastructure without measurable benefit
- solve hypothetical future problems

---

# 40. No Premature Generalization

Do NOT generalize every discovery into a new Mega-SDD capability.

Classify each finding:

```text
GENERAL
DOMAIN-SPECIFIC
PROJECT-SPECIFIC
```

Only promote something into the core Mega-SDD when there is a strong reason.

For example:

```text
Host-AS400-Batch requires:
batch-trigger extraction
```

Do NOT automatically conclude:

```text
Mega-SDD needs 7 new batch-specific skills
```

Instead determine whether one existing capability can handle it.

---

# 41. Prefer Skill Composition Over Skill Explosion

Before creating a new skill, ask:

> Can an existing skill be extended or composed to solve this problem?

Prefer:

```text
Existing Skill
      +
Small Capability
      =
Improved Skill
```

over:

```text
Existing Skill
      +
Skill A
Skill B
Skill C
Skill D
Skill E
      =
Complex Orchestration
```

Create a new skill ONLY when:

1. The responsibility is clearly distinct.
2. Existing skills cannot reasonably handle it.
3. The new skill is reusable.
4. The maintenance cost is justified.
5. The performance/token impact is acceptable.

---

# 42. Avoid Excessive Validation

Validation is valuable, but validation itself has cost.

Do NOT create validation for every possible theoretical problem.

Prioritize validation that catches errors which can materially affect:

- business logic
- data integrity
- system behavior
- dependencies
- implementation correctness
- AI interpretation

Use risk-based validation.

For example:

```text
CRITICAL
Business Rule Validation
Requirement/Evidence Validation
Dependency Validation

OPTIONAL
Formatting Validation
Stylistic Validation
Low-impact Metadata Validation
```

---

# 43. Establish a "Do Nothing" Option

For every major proposed change, explicitly evaluate:

> **What happens if we don't change anything?**

If the current system already performs adequately, the correct decision may be:

`KEEP CURRENT DESIGN`

Do not change architecture simply because an improvement is theoretically possible.

---

# 44. Establish an "80/20 First" Strategy

Prioritize changes that produce the largest improvement with the smallest implementation cost.

For example:

```text
P0
Fix incorrect information

P1
Fix missing critical business behavior

P1
Improve requirement traceability

P2
Improve AI readability

P3
Architectural optimization

P4
Nice-to-have automation
```

Do not spend significant engineering effort on P3/P4 while P0/P1 problems remain.

---

# 45. Define a Complexity Budget

Recommend a practical complexity budget for Mega-SDD.

The goal is not a fixed numeric limit.

Instead define constraints such as:

```text
Maximum reasonable number of skills
Maximum orchestration depth
Maximum repeated LLM calls
Maximum unnecessary context loading
Maximum duplication between skills
Maximum generated documentation overhead
```

If the current architecture is already within a healthy range, explicitly state:

`NO CHANGE REQUIRED`

Do not invent arbitrary complexity limits.

---

# 46. Optimize for Incremental Evolution

Mega-SDD should evolve incrementally.

Prefer:

```text
Audit
 ↓
Small Improvement
 ↓
Measure
 ↓
Validate
 ↓
Adopt
 ↓
Next Improvement
```

Avoid:

```text
Audit
 ↓
Complete Architecture Rewrite
 ↓
Huge Refactor
 ↓
Long Implementation Cycle
 ↓
Unknown Result
```

Do not recommend a rewrite unless there is strong evidence that incremental improvement cannot solve the identified problems.

---

# 47. Define Success Metrics

Every significant Mega-SDD improvement should have a measurable success criterion.

Examples:

```text
PRD completeness improves
Requirement ambiguity decreases
Unsupported requirements decrease
Traceability increases
Repeated context decreases
LLM calls decrease
Token usage decreases
Execution time decreases
Manual correction decreases
Implementation rework decreases
```

Where measurement is not currently possible, recommend a lightweight measurement mechanism.

Do NOT build a complicated observability system just to measure small improvements.

---

# 48. Final Decision Framework

For every proposed change, classify it as:

### MUST HAVE

Required to prevent materially incorrect AI behavior.

### SHOULD HAVE

Meaningful improvement with reasonable cost.

### NICE TO HAVE

Useful but not important enough to prioritize now.

### NOT NEEDED

The current Mega-SDD already handles it sufficiently.

### OVERENGINEERING

The proposed solution is more complex than the problem warrants.

This classification is mandatory.

---

# 49. Final Mega-SDD Recommendation

The final recommendation MUST answer:

1. Is the current Mega-SDD already efficient?
2. Which parts are already good and should NOT be changed?
3. Which parts are genuinely weak?
4. Which problems are PRD problems versus Mega-SDD problems?
5. What is the smallest change that fixes each important problem?
6. Which proposed improvements are unnecessary?
7. Which improvements would increase token cost?
8. Which improvements would increase execution time?
9. Which improvements would increase maintenance complexity?
10. What should be implemented now?
11. What should explicitly NOT be implemented?
12. What should be deferred until real evidence shows it is necessary?

The recommendation must favor:

> **Simple > Complex**

when both provide equivalent outcomes.

And:

> **Proven value > Theoretical capability**

when prioritizing engineering work.

---

# 50. Non-Negotiable Engineering Principle

While evolving Mega-SDD:

**NEVER sacrifice delivery speed, token efficiency, or maintainability merely to achieve architectural perfection.**

The purpose of Mega-SDD is to accelerate software engineering.

If Mega-SDD itself becomes slow, expensive, difficult to maintain, or overly complicated, then the system is failing its primary objective.

Always ask:

> "Are we building a better Mega-SDD, or are we just building a more complicated Mega-SDD?"

Choose the former.
