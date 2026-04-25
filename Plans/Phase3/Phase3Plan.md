# Phase 3 — Core Loop Completion (planning doc)

**Canonical gate:** [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 3 row: structure/enemy expansion, reward pipeline, scripted climax, onboarding).

**Design lock:** [docs/GDD.md](../../docs/GDD.md) §3 (onboarding), §4–5 (pre-endless arc, base, dual loss), §7–7.2 (economy, crafting, **structure roster**), §8 (scoring intent for reward-related design), §9–**10.3** (map, **six** roles, **wave 9** preview, **wave 10** **siege** climax — **not** a bespoke **boss**).  
**Roster (authoritative):** GDD **§7.2**; extra detail in archive [StructureRosterPlacementRulesPlan.md](../Archived/StructureRosterPlacementRulesPlan.md) (if archive conflicts, **GDD** wins).

## Purpose

Fill **pre-endless** loop quality: enough structures, enemy **roles**, rewards, a **scripted climax**, and **onboarding** so sessions hit target pacing and losses read as **tactical**, not **confusing**.

## In scope (Phase 3)

| Area | Intent |
|------|--------|
| **Structures / placement** | Expand beyond the Phase 2 **Sentry Turret**-class slice — add **N** additional structures from GDD **§7.2** and/or in-place **tier upgrades** (GDD §7.1). Not required to ship the full five-structure roster; scope to the gate. |
| **Enemies** | **Six-role** **teaching** spine and intro order (GDD **§10.1–10.2**): Swarm, Bruiser, Disruptor, Artillery, **Siege**, **Elite** (skirmisher) — so “what answers this wave?” is learnable. |
| **Reward pipeline** | Replace “reward stub” with a real between-wave or post-wave **upgrade / tech** flow tied to GDD **Upgrade choice** and **Resolution** (GDD §4). |
| **Scripted climax** | **Wave 10** **siege** set piece; **wave 9** = **siege preview** (GDD **§10.3**). **No bespoke boss** AI. Milestone **banner**, same run into Phase 4 **endless** handoff. |
| **Onboarding** | First-run beats per GDD **§3** (standard 2–4 min target); not **confusion-limited**; supports **Phase 3 → 4** comprehension test. |
| **Combat readability** | **Base** and **structure** HP / damage feedback: archived [StructureContext.md](../Archived/StructureContext.md) deferred **structure HP** to post–Phase 2; if still true, Phase 3 should harden **base + structure** damage UX so base defense stays legible. |

## Out of scope (Phase 3)

Defer to **Phase 4** per `Development-Phases` — see [Plans/Phase4/Phase4Plan.md](../Phase4/Phase4Plan.md):

- **Endless** driver and **mutator** system (sustained post-climax pressure).
- **Full score bus**, inspectable **results breakdown** persistence, **personal best** pipeline (GDD §8 implemented end-to-end).

(Phase 3 may still **emit** simple score or reward events if needed for the reward loop — but “credible endless + score integrity” is Phase 4’s gate.)

## Owner mapping (from gate)

- **Content + onboarding owners** (product/doc framing): structure/enemy expansion, climax content, reward cadence, onboarding copy and beats.
- **Engineering** follows existing bounded contexts; this file does not prescribe implementation paths.

## Exit criteria (must match `Development-Phases`)

- **Hard deliverables present:** structure/enemy role expansion, reward pipeline, scripted climax, onboarding beats.
- **Exit gate:** sessions **stabilize near target length**; losses are **tactical, not confusion-driven** (GDD target session ~20–30 min to peak pressure — see GDD §3).
- **Validation matrix:** core loop **pacing** test; **onboarding comprehension** test; [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) (Phase 3 → 4 row).

## Dependencies

- **Phase 2** complete per [Phase2CompletionChecklist.md](../Phase2/Phase2CompletionChecklist.md) (vertical slice, base + dual loss readable).

## See also

- [Phase3CompletionChecklist.md](Phase3CompletionChecklist.md) — pass/fail checkboxes for this phase.
