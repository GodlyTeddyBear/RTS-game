# Phase 7 — Co-op Product Phase (planning doc)

**Canonical gate:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 7 row: session model, scaling model, disconnect/rejoin, anti-grief, co-op UI clarity).

**Design lock:** [docs/GDD.md](../../docs/GDD.md) §12 (co-op **constraints** — threat scaling, resource model, revive/bleed reserved so v1 solo does not require a rewrite).  
**Planning lock unknown:** `Development-Phases` — **Co-op resource/life model** resolved by **Phase 7 planning lock**; fallback: *shared wave pressure, explicit revive rule, no silent carry-over assumptions*.

## Preconditions (org gate)

[GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) **Ship → Phase 7:** **Solo baseline** is **stable post-release**; **co-op** work starts only after the **solo baseline health** target is met — do not parallelize co-op before this.

## Purpose

Add **two-player (or wider) co-op** on top of the shipped **solo** systems **without** a **core loop rewrite**: networking, session ownership, how **pressure** and **economy** scale, what happens on **disconnect/rejoin**, **anti-grief** floor, and **UI** that makes roles and state legible.

## In scope (Phase 7)

| Area | Intent |
|------|--------|
| **Session model** | How players join, host, sync into a run, and leave — server-authoritative session truth. |
| **Scaling model** | Threat / wave budget vs player count (GDD §12 reserved: per-player addends vs shared budget — **decide and implement**). |
| **Resource model** | Shared pool vs split **Energy / Ferrium / Ceren / Voltrite / Scrap** (GDD **§7**) — GDD **§12** + `Development-Phases` **co-op** unknown; **explicit**, no ambiguous carry-over. |
| **Life / loss** | Revive, bleed, or run-end rules when **one** commander dies (GDD: solo **base or commander** loss may need **co-op exception**). |
| **Disconnect / rejoin** | Policy path with **deterministic** outcomes; ties to `Development-Phases` **Persistence** test scenarios 5–7. |
| **Anti-grief basics** | Minimal bar: kick, vote, or constraints so public co-op is not a free-for-all (document **grief-handling policy**). |
| **Co-op UI clarity** | Who is who, shared objectives, prep ownership if applicable, loss/reason strings. |

## Out of scope (Phase 7)

- Rebuilding **solo** loop, **endless**, or **meta** from scratch — extend, do not replace.
- **Campaign** or **competitive PvP** (out of org v1 scope unless product changes).

## Owner mapping (from gate)

- **Networking + session owners** (and design for life-model decisions).

## Exit criteria (must match `Development-Phases`)

- **Hard deliverables:** session model, scaling model, disconnect/rejoin policy, anti-grief basics, co-op UI clarity.
- **Exit gate:** **Two-player** runs are **stable** with **explicit grief-handling policy**.
- **Validation:** align with test matrix **Persistence** / session cases for co-op where applicable.

## Dependencies

- **Solo v1** shipped and baseline healthy per **Ship → Phase 7** gate.
- Engineering: [Phase6CompletionChecklist.md](../Phase6/Phase6CompletionChecklist.md) complete (or equivalent ship bar) for the **solo** product you are extending.

## See also

- [Phase7CompletionChecklist.md](Phase7CompletionChecklist.md) — pass/fail checkboxes for this phase.
