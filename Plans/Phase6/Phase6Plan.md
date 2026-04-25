# Phase 6 — Polish + Ship Prep (planning doc)

**Canonical gate:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 6 row: perf budgets, telemetry, error reporting, UX readability, bug bash, **rollback-ready** release process).

**Design lock:** GDD **pillars** (Tactical clarity, Meaningful prep, Escalating adaptation, Score integrity) as **readability** and **friction** bars for UX; org [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) **Success Criteria** (performance, exploit-resistant systems, content-complete v1, rollback-safe tuning where applicable).

## Purpose

Move from “feature complete” to **production ready** for a **solo v1** ship: measurable **performance** envelopes, **observability** (telemetry, errors), **clarity** passes, a disciplined **bug bash**, and a **release** process that can **roll back** bad builds without data carnage.

## In scope (Phase 6)

| Area | Intent |
|------|--------|
| **Performance budgets** | Declared and **enforced** (or gating) for entity counts, pathing, VFX, etc. — ties to `Development-Phases` risk: *Performance collapse* (Gate 6) and test **High-wave stress** (Phases 4–6). |
| **Telemetry** | Crashes, frame issues, run funnel, tuning mistakes; include **score/mutator**-relevant **audit** ideas from GDD **§8** (pillar counts, run length, max wave, mutator ids per wave, **anomaly** flags) where product agrees. |
| **Error reporting** | Server and client error surfaces: actionable logs, not silent failures for critical paths. |
| **UX readability** | One pass on HUD, results, mutators, loadout, and loss reasons so the **pillars** are not undermined by UI noise. |
| **Bug bash** | Systematic pass with triage; **critical** crash classes and blockers **cleared** for ship. |
| **Release process** | **Rollback-ready** deploy/tuning story — hotfix path, version pinning, and profile compatibility rules (`Development-Phases` in-scope: production hardening, release hygiene). |
| **Content-complete v1** | **Defined** and **met** per product — not open-ended “more content”; checklist agreed with owners. |

## Out of scope (Phase 6)

- **Co-op** (Phase 7) — do not block solo ship for multiplayer work.
- **New major systems** — avoid scope creep; only fixes/polish required for v1 quality bar.

## Owner mapping (from gate)

- **Performance + release owners** (and embedded QA/UX as your org defines).

## Exit criteria (must match `Development-Phases`)

- **Hard deliverables:** perf budgets, telemetry, error reporting, UX readability pass, bug bash, rollback-ready release process.
- **Exit gate:** **Soak** testing has **no critical crash class**; **v1 content-complete** definition is **met**.
- **Validation matrix (Phase 6 → Ship):** **Soak, perf, telemetry, rollback drill** — *Release checklist complete with no critical crash class*; see [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) line 177.
- **Org success criteria** (where applicable): median session band, score/trust, exploit-resistance at v1 scope — per [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) lines 15–19.

## Dependencies

- **Phase 5** complete per [Phase5CompletionChecklist.md](../Phase5/Phase5CompletionChecklist.md) (or explicit waiver of meta scope if you ship a slimmer v1 — document the cut).

## See also

- [Phase6CompletionChecklist.md](Phase6CompletionChecklist.md) — pass/fail checkboxes for this phase.
- **Post-ship:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) *Ship -> Phase 7* — co-op only after **solo baseline** health; see [Plans/Phase7/Phase7Plan.md](../Phase7/Phase7Plan.md).
