# Phase 5 Completion Checklist

Aligned with [Phase5Plan.md](Phase5Plan.md), [docs/GDD.md](../../docs/GDD.md) §11, and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 5: Meta Progression).

Use this checklist to decide whether Phase 5 is complete.

## Unlocks and loadouts

- [ ] **Unlock system** is implemented: players earn or unlock **new options** (horizontal bias per GDD §11; avoid default flat +damage to all content)
- [ ] **Loadout** (or equivalent pre-run pick) is implemented and **server-respected** — no client-only unlock state for run eligibility
- [ ] A **v1 progression set** is defined and shippable (what exists, what is earnable, caps if any)

## Profile and migration

- [ ] **Profile / meta state** matches **data contract** decision: versioned **unlock + loadout** schema (see `Development-Phases` meta row)
- [ ] **Migration** path exists for at least one schema bump without wiping players (or explicit wipe policy is documented and accepted)
- [ ] Unlocks **persist** across sessions; no silent loss of progression class

## Retention and fairness (exit gate)

- [ ] **Session-2 retention** (or your agreed return metric) hits the **internal threshold** in testing
- [ ] **Progression fairness** check: **veteran** or fully unlocked loadouts do not **trivialize** early waves / endless entry vs **baseline** new-player expectations (`Development-Phases` risk: power creep)
- [ ] GDD bar: **meta** progression does not **undermine endless scoring** identity (GDD §11) in review

## Security and authority

- [ ] **Unlock grants** and loadout changes are **server-authoritative** or server-validated (align with project networking rules in `Development-Phases`)

## Phase 5 exit check

- [ ] [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) Phase 5 hard deliverables and exit gate are satisfied
- [ ] **Phase 5 → 6** validation ready: **Meta retention** + **progression fairness** review passed
- [ ] The build is ready for **Phase 6** — [Phase6Plan.md](../Phase6/Phase6Plan.md) (polish, ship prep, perf, telemetry, bug bash; see Development-Phases Phase 6 row)
