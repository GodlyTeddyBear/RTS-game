# Content Plan

This document is the full v1 content matrix for RTS.
It turns the GDD spine into a concrete roster of structures, enemies, rewards, mutators, and meta unlocks that can be tuned and implemented without reopening the design.

When this doc conflicts with [docs/GDD.md](../docs/GDD.md) or [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md), the GDD and phase gates win.

---

## Purpose

- Define the actual content set for the solo v1 game.
- Keep content aligned to the existing tactical pillars: readability, meaningful prep, escalating adaptation, and score integrity.
- Give design, art, and engineering one place to read what exists, when it appears, and what problem it solves.

## Content Locks

- Single lane, solo-first run structure.
- Base and commander are both valid loss conditions.
- Wave 10 is a scripted siege climax, not a bespoke boss.
- Endless mode uses at most 2 active mutators at a time.
- Meta progression should be horizontal by default, not raw stat creep.

## Content Matrix

### 1. Structures

| Structure | Job | First phase | Primary counterplay | Content note |
|---|---|---:|---|---|
| Sentry Turret | Reliable single-target lane DPS | Phase 2 | Swarm pressure, armor checks, range pressure | Baseline structure. Should teach "steady damage matters." |
| Stasis Field | Lane slow and tempo control | Phase 3 | Fast enemies, Disruptor timing, spread waves | Should help the player re-stabilize bad prep windows. |
| Arc Pylon | AOE and clump punishment | Phase 3 | Spread formations, Artillery spacing, high-HP targets | Best when the player can force enemies into tight lanes. |
| Bulwark Projector | Stabilization, absorb, or short hold | Phase 3 | Siege pressure, sustained focus fire, anti-stall rules | Must buy time without creating a permanent wall. |
| Relay Beacon | Commander or summon tempo support | Phase 4+ | Mutators that suppress ability loops, low-energy runs | Should improve decision variety, not flatten challenge. |

#### Structure design rules

- Each structure should solve a different tactical problem.
- Tiers should change behavior where possible, not only numbers.
- Structure identity must remain readable from silhouette and combat effect.
- No structure should become the default answer to every wave.

### 2. Enemies

| Enemy role | What it teaches | Weakness | First phase | Content note |
|---|---|---|---:|---|
| Swarm | Coverage, area damage, tempo control | Single-target overkill, control tools | Phase 2 | Early teaching enemy. Use it to establish lane pressure. |
| Bruiser | Sustained focus fire and target priority | Strong sustained DPS and baiting summons | Phase 2 to 3 | Teaches the player to commit resources instead of reacting late. |
| Disruptor | Rhythm breaks and lost-value punishment | Re-stabilization tools, positioning discipline | Phase 3 | Should make the player notice bad timing, not randomize failure. |
| Artillery | Range and geometry pressure | Positioning, lane denial, mobility | Phase 3 | Introduces unsafe open-field commander play. |
| Siege | Base and extractor pressure | Repairs, stasis, bulwark, resource protection | Phase 3 | Must read as objective pressure, not as a boss substitute. |
| Elite | Punishes greed, spacing mistakes, and panic | Baiting, summon use, mobility | Phase 3 to 4 | Use in doses so it does not overwhelm the teaching spine. |

#### Enemy design rules

- Roles come before raw stat inflation.
- Every new role needs a one-line explanation the player can learn in play.
- At least one clear counterplay should exist for each role.
- Siege pressure must always be understandable as pressure on the base or resource economy.

### 3. Wave And Encounter Content

| Content beat | Goal | First phase | Notes |
|---|---|---:|---|
| Waves 1 to 2 | Teach lane defense, basic coverage, and first prep loop | Phase 2 | Mostly Swarm, with a light Bruiser tease if needed. |
| Mid waves | Add one new answer at a time | Phase 3 | Introduce Disruptor and Artillery separately so each lesson is readable. |
| Wave 9 | Siege preview | Phase 3 | First serious base and extractor pressure, lower than the climax. |
| Wave 10 | Scripted siege climax | Phase 3 | Peak pressure, milestone banner, same run continues into endless. |
| Endless waves | Test adaptation under mutators | Phase 4 | Pressure should come from rule changes, not only bigger numbers. |

#### Encounter design rules

- Introduce one new idea per wave beat when possible.
- Do not stack too many new lessons in one wave.
- Siege content must feel like escalation of the same run, not a separate boss phase.
- Endless content should reuse known roles under changing mutator rules.

### 4. Endless Mutators

| Mutator | Rule | Content role |
|---|---|---|
| No Step | Blink Step is disabled for the wave | Mobility denial |
| Scramble Drones | Swarm Drones deal 50 percent damage | Summon suppression |
| Gravity Heavy | Gravity Pulse knockback and slow are reduced | Control resistance |
| Stun Leak | Overcharge Field stun duration is reduced | Ultimate pressure |
| Extractor Siphon | Extractors produce 50 percent for the wave | Economy pressure |
| Rationing | Ability Energy costs increase | Resource strain |
| Thin Prep | Next Prep is shorter | Planning pressure |
| Shorter Reach | Defensive structures lose some range | Lane pressure |
| Shuttered Targeting | Structures warm up before first shot | Setup disruption |
| Reclaim Tax | Scrap conversion tax increases next Prep | Conversion pressure |
| Pulse Tax | Gravity Pulse cooldown increases | Ability timing pressure |
| Swarm Resurgence | A second Swarm batch spawns late in the wave | Aggression pressure |

#### Mutator design rules

- Mutators must change behavior, not only stats.
- Active mutators must always be shown with plain-language rules.
- At most 2 mutators are active at once.
- Mutator combinations should be hard but fair, not surprise failure.

### 5. Rewards And Upgrade Choices

| Reward type | Purpose | First phase | Notes |
|---|---|---:|---|
| Structure tier upgrade | Improve an existing structure and change how it behaves | Phase 3 | Should be the default reward shape for core loop expansion. |
| New structure unlock | Expand the tactical roster | Phase 3 to 5 | Use to introduce new answers, not raw damage creep. |
| Commander module choice | Add a new tactical option or variation | Phase 4 to 5 | Must not become a flat stat sticker by default. |
| Economy or conversion perk | Adjust prep decisions and resource flow | Phase 4 | Can support endless or score-focused play. |
| Run-specific tech choice | Temporary run modifier with clear tradeoff | Phase 3 onward | Good for reward cadence between waves. |

#### Reward design rules

- Rewards should expand decision space before they increase raw power.
- Reward text must explain what changed and what it costs.
- If a reward helps everything equally, it is probably too flat.
- Rewards should feed the score identity instead of bypassing it.

### 6. Meta Unlocks And Loadouts

| Meta element | Purpose | First phase | Notes |
|---|---|---:|---|
| Unlock track | Give the player new options over time | Phase 5 | Horizontal unlock bias only. |
| Loadout selection | Let the player choose a pre-run setup | Phase 5 | Must be server respected and profile backed. |
| Commander variants or modules | Support different play styles | Phase 5 | Should alter approach, not trivialize difficulty. |
| Structure access gating | Let progression open new tactical branches | Phase 5 | Good fit for phase-gated content unlocks. |
| Profile migration versioning | Keep progression safe across schema changes | Phase 5 | Required so future content does not brick saves. |

#### Meta design rules

- Meta progression should add options, not mandatory power.
- Unlocks must not flatten early waves or endless score pressure.
- Loadout choices should create meaningful tradeoffs.
- Any profile schema change needs a migration or an explicit wipe policy.

## Recommended v1 Content Set

### Phase 2 foundation

- Sentry Turret
- Swarm
- Basic reward stub
- First-run onboarding beats

### Phase 3 expansion

- Stasis Field
- Arc Pylon
- Bulwark Projector
- Bruiser
- Disruptor
- Artillery
- Structure upgrade choices
- Wave 9 siege preview
- Wave 10 siege climax

### Phase 4 expansion

- Relay Beacon
- Endless mutators
- Score-facing run rewards or tech choices
- Results breakdown content
- Personal best presentation hooks

### Phase 5 expansion

- Unlock track
- Loadout selection
- Profile versioning and migration
- Horizontal meta progression set

## Tuning Questions

- How many total unlocks should exist in the Phase 5 v1 set?
- Which structure tiers should change behavior versus only numbers?
- Which content rewards are permanent unlocks and which are run-only choices?
- What is the minimum readable wave count before the climax feels earned?
- Which mutator pairs should be banned if readability drops too far?

## Validation Checklist

- Every content item has a job, a first phase, and a counterplay note.
- No content item violates the GDD locks.
- Structures and enemies are diverse enough that each role has a reason to exist.
- Reward choices expand the decision space instead of flattening difficulty.
- Meta unlocks preserve early-wave challenge and endless score integrity.

