# Phase 3 Completion Checklist

Aligned with [Phase3Plan.md](Phase3Plan.md), [docs/GDD.md](../../docs/GDD.md), and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 3: Core Loop Completion).

Use this checklist to decide whether Phase 3 is complete.

## Structures and development

- [ ] **More than one** structure type is in the build (Phase 2 had exactly one) and/or **in-place building tier upgrades** are implemented (GDD §7.1)
- [ ] Placed structures remain readable under **base defense** pressure (GDD **Enemy design goal**)
- [ ] If structure HP was deferred from Phase 2, **structure damage and HP** are clear in combat (see [StructureContext.md](../Archived/StructureContext.md) note in Phase3Plan)

## Enemies and teaching

- [ ] **Multiple enemy roles** (GDD **§10.1** **six**-role spine) are implemented with consistent behavior; at minimum **Swarm, Bruiser, Disruptor, Artillery, Siege, Elite** are distinguishable
- [ ] **Introduction / ramp order** matches GDD **§10.2** (tuning wave numbers, order locked)

## Rewards

- [ ] **Reward pipeline** is more than a stub: between-wave or post-wave **upgrades / tech** (GDD §4 **Upgrade choice** + **Resolution**)
- [ ] Rewards feel tied to **wave outcomes** and player choices, not random noise

## Scripted climax

- [ ] **Wave 9 (default):** **siege preview** — first **serious** **base/Extractor** pressure, **less** than wave 10 (GDD **§10.3**)
- [ ] **Wave 10 (v1):** **siege** set-piece **climax** — **not** a bespoke **boss**; includes **Disruptor** and/or **Artillery** with **Siege** so the wave is not **Sentry**-only solvable; milestone **UI**, then hand off to **endless** in Phase 4

## Onboarding

- [ ] **First-run** onboarding matches GDD **§3** (lane goal, **prep**, **Scrap** + **Ferrium/Ceren/Voltrite** legend where applicable, one **ability** beat, first **wave**)
- [ ] Comprehension pass: after first loop, player can name at least one of **base** pressure, **commander** loss, or **pocket/Extractor** consequence (GDD **§3**)
- [ ] New players are tested for **comprehension** (not just completion) per Phase 3 → 4 validation plan

## Pacing and outcome quality (exit gate)

- [ ] Session length trends toward GDD **~20–30 minutes** to peak pressure in internal playtests
- [ ] **Confusion-driven** losses are reduced vs Phase 2; remaining losses are **tactical** and attributable (GDD Tactical clarity)
- [ ] Stakeholders agree the pre-endless **core loop** is “content-complete enough” to start Phase 4 (endless + score)

## Phase 3 exit check

- [ ] [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) Phase 3 hard deliverables and exit gate are satisfied
- [ ] The build is ready for **Phase 4**: endless driver, mutators, score bus, results breakdown (see Development-Phases Phase 4 row)
