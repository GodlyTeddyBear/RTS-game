# Plan Development Standard

Use this standard when generating implementation-ready plans for features.

The default output is two-tier:
1. Concise GDD (what/why)
2. Decision-complete implementation plan (how)

---

## Stable Output Contract

Every planning response must include these sections in this order:

1. `Goal`
2. `Success Criteria`
3. `In Scope / Out of Scope`
4. `Unknowns + Resolution Plan`
5. `GDD Section`
6. `Implementation Section`
7. `Validation & Test Matrix`
8. `Rubric Score + Pass/Fail + Blocking Gaps`

Do not omit sections. If information is unavailable, mark it explicitly as unknown.

---

## GDD Required Fields

The `GDD Section` must include:
- Problem statement
- Target player
- Core loop impact
- Goals
- Non-goals
- Constraints
- Success metrics
- Acceptance criteria

Acceptance criteria must be measurable and observable in-game.

---

## Implementation Plan Required Fields

The `Implementation Section` must include:
- Architecture boundaries (client/server/shared and context ownership)
- Data contracts (state shapes, persistence shapes, payload schemas)
- Network contracts (RemoteEvent/RemoteFunction direction, payload validation)
- Validation and security rules (server authority and anti-exploit checks)
- Sequencing (ordered steps with dependencies)
- Risks and mitigations
- Test scenarios (functional, edge, security, performance)

Implementation steps must be owner-scoped and include completion checks.

---

## Clarity Rules

Every requirement in both sections must be:
- Testable: can be verified with a concrete pass/fail check
- Owner-scoped: has a clear owner module/layer/context
- Observable: has a visible or inspectable outcome

Reject vague items such as "improve feel" unless paired with measurable criteria.

---

## Ambiguity Handling

Before proposing architecture:
- List unknowns that materially affect design or sequencing.
- Ask targeted, high-impact clarifying questions when needed.
- If unanswered, choose explicit defaults and record them as assumptions.

Never invent product intent silently.

---

## Rubric And Gates

Score each category from 0 to 2:
- Clarity
- Completeness
- Feasibility
- Verifiability
- Risk Coverage

Scoring guidance:
- 0 = missing or unusable
- 1 = partial, ambiguous, or weakly specified
- 2 = implementation-ready

Pass threshold:
- Total score must be at least `8/10`
- `Clarity` and `Verifiability` must both be `2/2`

Hard fail conditions (automatic `Not Approved`):
- Missing acceptance criteria
- Undefined client/server/shared boundaries
- Unowned implementation tasks
- Untestable claims

---

## Approval Status

The final section must end with one status:
- `Approved` (all gates pass)
- `Not Approved` (one or more gates fail)

When `Not Approved`, include explicit `Blocking Gaps` and the minimum actions required to pass.

---

## Verbosity Policy

Default to concise output.

Expand detail only for:
- High-risk systems (security, persistence, networking)
- High-complexity flows (multi-context, migration, race-prone sequencing)
- Areas with unresolved unknowns
