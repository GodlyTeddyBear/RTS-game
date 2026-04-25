# Phase 4 — Endless + Score (planning doc)

**Canonical gate:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 4 row: endless driver, mutator system, score bus, results breakdown, personal best persistence).

**Design lock:** [docs/GDD.md](../../docs/GDD.md) §4–5 (post-climax **endless**, lose conditions), **§8** (three **pillars**; **Aggression** weighted highest in v0; inspectability, anti-exploit, post-run + telemetry **intent**), **§10.4** (**2** **active** mutators, **12**-entry **deck**, **rotation** every **N** waves — **N** in tuning; “hard but fair” tone).  
**Data contract:** [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) — **Score state** (pillar breakdown + audit fields) finalized by **Phase 4**; **resource** names are **GDD-locked** in **Phase 1–3**.

## Purpose

Ship a **credible endless** mode after the scripted climax, with **mutators** that change rules in a **readable** way, and a **score** pipeline that is **trustworthy**: post-run breakdown explains gains/losses, **exploit loops** have **counters**, and **personal bests** persist without client trust issues.

## In scope (Phase 4)

| Area | Intent |
|------|--------|
| **Endless driver** | After the main arc / climax, waves continue (GDD §4–5) until a lose condition. Hand-off from Phase 3 climax must be stable (no double-state bugs). |
| **Mutator system** | GDD **§10.4**: use the **v0 deck**; mutators change **rules**, not only stats. **At most 2** **active**; **readability** first (`Development-Phases` risk: *Endless mode lacks readability*). |
| **Mutator cadence** | **GDD-locked:** **2**-slot cap + **rotation** (period **N** waves — tune in **Phase 4**). Optional: **pairing** bans and extra cards beyond 12. |
| **Score bus** | Server-authoritative events for **Efficiency, Aggression, Control**; **v0** bias toward **Aggression** per GDD **§8**; all totals **server-owned** ([GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md): client cannot mutate score). |
| **Results breakdown** | UI + data: player can answer “why these points?” for most runs (aligns with **Score integrity** pillar and org success criteria: ~90% of reviewed runs explicable). |
| **Personal best persistence** | Profile-owned or context-owned **PB** with versioning/migration as needed (ties to `Development-Phases` meta unknowns; PB is Phase 4 deliverable, full meta in Phase 5). |
| **Exploit and abuse** | `Development-Phases` unknown: **Score exploit policy thresholds**; fallback: **disable leaderboard publish** until checks pass. **Exploit pass** in Phase 4 → 5 validation. |

## Out of scope (Phase 4)

Defer to **Phase 5+** per `Development-Phases` — see [Plans/Phase5/Phase5Plan.md](../Phase5/Phase5Plan.md):

- **Meta progression** full system (unlock grid, loadouts, horizontal progression **set** — Phase 5).
- **Co-op** — [Plans/Phase7/Phase7Plan.md](../Phase7/Phase7Plan.md) (after solo ship).
- **Ship** polish, perf budgets, full telemetry productization (**Phase 6**), though performance stress for **high-wave endless** is in test matrix for Phases 4–6.

## Owner mapping (from gate)

- **Runtime + scoring owners:** endless loop, mutators, server score pipeline, persistence of PB, exploit detectors / policies.

## Exit criteria (must match `Development-Phases`)

- **Hard deliverables:** endless driver, mutator system, score bus + results breakdown, personal best persistence.
- **Exit gate:** **Score breakdown** answers gain/loss logic for **most** runs; **exploit loops** have **counters** (or publishing gated).
- **Validation matrix (Phase 4 → 5):** **Endless stability** test, **score audit** review, **exploit pass** — *Score trust gate approved*; see [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) line 175.
- **Risks table:** clarity of active mutator rules; score gamed by low-interaction loops — both have mitigations tied to this phase.

## Dependencies

- **Phase 3** complete per [Phase3CompletionChecklist.md](../Phase3/Phase3CompletionChecklist.md) (pre-endless core loop, climax, onboarding bar).

## See also

- [Phase4CompletionChecklist.md](Phase4CompletionChecklist.md) — pass/fail checkboxes for this phase.
- [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) — test scenarios: **Client attempts score mutation** (4–7), **High-wave stress** (4–6).
