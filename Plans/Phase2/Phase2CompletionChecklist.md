# Phase 2 Completion Checklist

Aligned with [docs/GDD.md](../../docs/GDD.md) §4–5, §9 and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 2: Vertical Slice).

Use this checklist to decide whether Phase 2 is complete.

## Core Loop

- [ ] Player teleports into the Phase 2 map from the hub or lobby
- [ ] Single lane is playable end-to-end
- [ ] Prep phase exists and clearly transitions into combat
- [ ] Combat phase runs on a repeatable wave loop
- [ ] Reward or breather step exists between waves
- [ ] Lane **spawn** point and **command post (base) at `base_anchor`** (lane terminus) are defined — enemies path toward the **base**; pressure on the base is **legible** (GDD §5, §9)

## Base (command post)

- [ ] **Command post (base)** exists, has HP, and is bound to a **base_anchor** (GDD §9)
- [ ] **Base loss** (base HP to zero) ends the run with deterministic results (matches `Development-Phases` base contract and edge: Base HP reaches zero)
- [ ] In the vertical slice, enemies **path toward and/or pressure the base** (minimal acceptable: readable threat even if simple)

## Content

- [ ] Exactly `6` hand-authored waves are implemented
- [ ] One enemy family is implemented and behaves consistently
- [ ] One structure exists and meaningfully changes the outcome of fights
- [ ] One summon or deployable exists and supports the commander fantasy

## Economy and Placement

- [ ] Placement rules match GDD **§7.1** / **§7.2** (Prep-only unlock/place when implemented; valid tiles)
- [ ] **Economy** matches GDD **§7** for the slice scope: **Energy**; **Ferrium / Ceren / Voltrite** from `side_pocket` extraction when implemented; **Scrap** from kills with **Prep** conversion; caps/overflow as in GDD (subset OK for early slice if documented)
- [ ] Resource and **Scrap** conversion UI readable for everything the slice implements
- [ ] Roster: single structure for slice aligns with GDD **§7.2** default (**Sentry Turret**); more structures in **Phase 3+**

## Commander Interaction

- [ ] Commander ability pipeline works
- [ ] Input reaches the server correctly
- [ ] Server validation is enforced
- [ ] Server execution completes successfully
- [ ] Client feedback is visible after ability use

## Audio and Feedback

- [ ] Minimal SFX exist for spawn
- [ ] Minimal SFX exist for hit
- [ ] Minimal SFX exist for death
- [ ] Minimal SFX exist for ability use
- [ ] Minimal SFX exist for UI confirm

## Playtest Quality

- [ ] A new player can understand **why they lost** without coaching — at minimum **base destroyed** (GDD **Loss (base)**) and **commander death** (GDD **Loss (commander)**) are distinguishable, not a vague “I died”
- [ ] The slice is fun enough to replay twice in one sitting
- [ ] No major authority or replication bugs remain in the slice loop

## Phase 2 Exit Check

- [ ] The build can be treated as a vertical slice rather than a prototype
- [ ] The slice is ready for Phase 3 content expansion

## Player Result

- [ ] The player arrives on a single-lane map and immediately understands the run context (defend the **base**, command the field)
- [ ] The player can prep, fight, and receive a clear outcome (win/loss) without needing explanation — including **base** vs **commander** fail states when relevant
- [ ] The final experience feels like a complete slice of the game, not just a test harness
