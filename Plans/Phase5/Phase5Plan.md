# Phase 5 — Meta Progression (planning doc)

**Canonical gate:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 5 row: unlock/loadout, profile migration/versioning, horizontal progression set).

**Design lock:** [docs/GDD.md](../../docs/GDD.md) §11 (meta — prefer **horizontal** unlocks before raw vertical power; do not trivialize early waves or endless scoring).  
**Data contract:** `Development-Phases` — **Meta state** (profile unlock/loadout schema) **versioned by Phase 5**.

## Purpose

Give **return motivation** after a run **without** flattening core difficulty: new **options** and **loadout** choices, not mandatory stat creep. Aligns with org pillar **Score integrity** and **Escalating adaptation** — veterans should still care about early-wave challenge.

## In scope (Phase 5)

| Area | Intent |
|------|--------|
| **Unlock system** | Horizontal unlocks (GDD §11): commander modules, mutators, structures, or other **options** — **not** a default of flat +damage/+HP on everything. |
| **Loadout** | Pre-run (or between-run) **selection** of what the player takes into a run, bounded by what is unlocked. |
| **Profile persistence** | **Migration / versioning** for meta saves so schema changes do not brick profiles (`Development-Phases` hard deliverable). |
| **Progression set** | A **defined v1 set** of unlocks and how they are earned (GDD **§11** — horizontal bias; no default flat **+damage** / **+HP**; earn rules product-owned). `Development-Phases` still tracks **meta depth** as an **unknown** until **Phase 5** sign-off. |
| **Fairness vs baseline** | Exit gate: **Session-2 retention** signal without **flattening** early-wave challenge — test **veteran** loadouts against **baseline** (see `Development-Phases` risk: *Meta progression power creep*). |

## Out of scope (Phase 5)

- **Co-op** — [Plans/Phase7/Phase7Plan.md](../Phase7/Phase7Plan.md) (after stable solo ship).
- **Ship** readiness: performance budgets, full telemetry, bug bash as **product** bar — see [Plans/Phase6/Phase6Plan.md](../Phase6/Phase6Plan.md) (**Phase 6**). Phase 5 may add persistence load but does not complete the polish/ship gate.

## Owner mapping (from gate)

- **Meta + profile owners:** unlock rules, loadout UI/flow, profile store, migrations, anti-fraud baselines for unlock grants if online.

## Exit criteria (must match `Development-Phases`)

- **Hard deliverables:** unlock/loadout system, profile migration/versioning, horizontal progression set.
- **Exit gate:** **Session-2 retention** bar met **without** flattening early-wave challenge.
- **Validation matrix (Phase 5 → 6):** **Meta retention** check, **progression fairness** check — *Retention signal passes internal threshold*; see [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) line 176.

## Dependencies

- **Phase 4** complete per [Phase4CompletionChecklist.md](../Phase4/Phase4CompletionChecklist.md) (score trust, endless + PB baseline).

## See also

- [Phase5CompletionChecklist.md](Phase5CompletionChecklist.md) — pass/fail checkboxes for this phase.
- **Test matrix:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) — **Persistence** mid-run / profile paths Phases 5–7 as applicable to your profile story.
