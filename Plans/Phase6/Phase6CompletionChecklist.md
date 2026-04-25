# Phase 6 Completion Checklist

Aligned with [Phase6Plan.md](Phase6Plan.md) and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 6: Polish + Ship Prep).

Use this checklist to decide whether Phase 6 is complete and the game is **ready to ship** solo v1 (before optional Phase 7 co-op).

## Performance

- [ ] **Performance budgets** are **written** (targets for entities, VFX, pathing budget, or frame-time envelope as appropriate to your stack)
- [ ] **High-wave** / **stress** scenarios stay within budget or have explicit waivers and follow-up (see `Development-Phases` test 4–6)
- [ ] No **systemic** frame collapse in soak on **target** hardware (define target devices)

## Observability

- [ ] **Telemetry** is in place for ship decisions (crashes, key funnel, perf markers) and supports **score** / **endless** debugging per GDD **§8** **telemetry** **intent** where scoped for v1
- [ ] **Error reporting** is wired for server and critical client paths; P0 errors are not silent

## Player-facing quality

- [ ] **UX readability pass** complete: prep/combat, results, score breakdown, loadout/meta, and **mutator** / loss messaging where applicable (GDD pillars)
- [ ] GDD **Tactical clarity** and **Meaningful prep** are not regressed by late UI clutter

## Stability and content

- [ ] **Bug bash** run; **critical** crash classes and **ship blockers** resolved or explicitly accepted with mitigation
- [ ] **Soak** testing: **no critical crash class** in extended sessions (`Development-Phases` exit gate)
- [ ] **v1 content-complete** definition is **agreed, documented, and met** (features, content scope, known limitations)

## Release

- [ ] **Rollback-ready** release process exercised (e.g. rollback drill) — can revert a bad build without undefined profile corruption
- [ ] Tuning/remote config or live-update story matches your risk (if any)

## Phase 6 exit check (ship)

- [ ] [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) Phase 6 hard deliverables and **Phase 6 → Ship** validation are satisfied
- [ ] Stakeholders sign off on **solo v1 ship**; **co-op (Phase 7)** remains **after** stable solo baseline per `Development-Phases` *Ship -> Phase 7* gate

## After ship (reference only)

- [ ] If pursuing **co-op:** [Phase7Plan.md](../Phase7/Phase7Plan.md) and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) *Ship → Phase 7* + GDD §12
