# Structure Roster + Placement Rules Plan

## Summary

This plan locks the GDD direction for structure roster and placement rules. It is a design artifact, not an implementation ticket.

The structure system uses a V1 core roster of five structures and a side-pad placement model beside the single lane. Phase 2 should only require one structure, while the rest of the roster becomes Phase 3+ content once the vertical slice proves the loop.

## Design Target

Structures are prep-phase tactical commitments. They should make the player choose between defense, tempo, commander safety, and future flexibility without becoming a passive economy engine or a zero-interaction turtle solution.

Primary constraints:

- Solo-first.
- Single lane.
- One primary resource: Energy.
- Commander death ends the run.
- Structures support tactical clarity and meaningful prep.
- Exact tuning numbers are deferred until playtesting.

## V1 Core Roster

| Structure | Job | Primary Counter | Weakness | Cost Band | Phase Target |
|---|---|---|---|---|---|
| Sentry Turret | Reliable single-target damage | Basic enemies, tanks, priority targets | Can overkill, weak into dense swarms | Medium | Phase 2 slice |
| Stasis Field | Slow/control zone projected onto the lane | Swarms, fast enemies, commander reposition pressure | Does not solve durable enemies by itself | Medium | Phase 3 |
| Arc Pylon | Chain or splash damage into grouped enemies | Dense waves, clustered swarms | Weak into sparse waves and high-HP tanks | High | Phase 3 |
| Bulwark Projector | Temporary barrier, taunt field, or damage absorber | Mistake recovery, burst pressure, lane stabilization | Limited uptime or coverage; cannot permanently block the lane | High | Phase 3 |
| Relay Beacon | Commander/summon support structure | Summon uptime, ability tempo, tactical repositioning | Depends on commander-kit finalization; weak if unsupported | Medium/High | Phase 4+ |

## Structure Roles

### Sentry Turret

- Teaches basic placement, lane coverage, and structure value.
- Fires at one enemy at a time.
- Should make Wave 1-2 outcomes visibly better when placed well.
- Should not clear swarms efficiently enough to remove the need for future control/AOE structures.
- This is the only required Phase 2 vertical-slice structure.

### Stasis Field

- Projects a slow/control area from a side pad onto the lane.
- Should make fast or dense waves more manageable without directly replacing damage.
- Encourages combined placement with Sentry Turret or commander abilities.
- Must be visually readable before and during combat.

### Arc Pylon

- Deals chain, splash, or pulse damage to grouped enemies.
- Rewards the player for predicting dense wave pressure.
- Should underperform against isolated high-HP threats.
- Must avoid excessive VFX spam or unbounded chaining in Roblox.

### Bulwark Projector

- Provides a stabilizing defensive effect from a side pad.
- Candidate effects: temporary lane barrier, taunt projection, damage absorption field, or shield zone.
- Must not permanently block pathing or soft-lock enemies.
- Should buy time for commander decisions rather than solve waves alone.

### Relay Beacon

- Supports the summoner/tactician fantasy.
- Candidate effects: improves nearby summon uptime, reduces commander ability friction, or enables tactical redeploy behavior.
- Exact function should wait until Commander Kit design is locked.
- Should not become a generic stat booster that trivializes early waves.

## Placement Rules

### Valid Placement

A placement is valid only when all rules pass:

- Current run state is `Prep`.
- Target tile is an explicit side pad or placement pad.
- Target tile is unoccupied.
- Structure type exists in the structure roster/config.
- Player has enough Energy.
- Run structure cap is not exceeded.
- Structure is available for the current phase/unlock/loadout rules.

### Invalid Placement

Placement must be rejected when:

- The run is in `Wave`, `Resolution`, `Climax`, `Endless`, or `RunEnd`.
- The target tile is the lane.
- The target tile is blocked.
- Another structure already occupies the pad.
- The client sends an invalid coord, invalid structure id, or malformed payload.
- The player cannot pay the Energy cost.

### Placement Space

- Structures can only be placed on explicit side pads beside the lane.
- The lane itself is not placeable.
- One structure occupies one pad.
- Multi-pad footprints are out of scope for V1.
- Freeform placement and commander-radius placement are out of scope unless playtests prove side pads are too restrictive.

### Placement Timing

- Structure placement is Prep-only.
- Repair, if implemented, is also Prep-only by default.
- Selling/reclaiming is deferred by default.
- Emergency wave-time placement is out of scope for V1 unless playtests show the loop needs it.

## Energy And Economy

All structures spend Energy.

Use cost bands in GDD until tuning:

- Low: cheap utility or early learning tool.
- Medium: normal structure commitment.
- High: high-impact or stabilizing structure.

Default economy stance:

- Sentry Turret should be affordable early enough to teach placement.
- Stasis Field and Arc Pylon should compete for Energy in different wave contexts.
- Bulwark Projector should be expensive enough that it is a conscious safety choice.
- Relay Beacon cost depends on final commander/summon kit.

Repair stance:

- Repair is a planned Energy sink.
- Repair should be allowed during Prep.
- Repair should not be free sustain.
- Repair can be deferred from Phase 2 implementation.

Sell/reclaim stance:

- Default: defer selling.
- Add partial refund only if playtests show players need mistake recovery.
- If added, selling should be Prep-only and should refund less than the original Energy cost.

## Anti-Turtle Rules

No structure should fully solve every wave role.

Each structure must have at least one meaningful limitation:

- Limited coverage.
- Role weakness.
- Energy repair pressure.
- High opportunity cost.
- Enemy-role counterplay.
- Later mutator counterplay.

Anti-turtle design checks:

- A static layout should not become safer forever without additional decisions.
- Defensive structures should still require commander action or structure variety.
- Long-term score should not reward zero-interaction stall strategies.
- Endless mutators may counter repeated overreliance on one structure type.

## Phase Rollout

### Phase 2: Vertical Slice

Implement or design around one structure:

- Sentry Turret.

Purpose:

- Prove placement.
- Prove Energy spending.
- Prove that a structure visibly changes wave outcome.
- Keep targeting and feedback simple.

### Phase 3: Core Loop Completion

Add:

- Stasis Field.
- Arc Pylon.
- Bulwark Projector.

Purpose:

- Introduce role-based structure choice.
- Support varied enemy pressure.
- Make wave prep decisions less obvious.

### Phase 4+

Add:

- Relay Beacon.

Purpose:

- Integrate structure play with commander/summon identity after the commander kit is stable.
- Avoid designing support effects before the supported kit exists.

## Implementation Implications

This plan does not require immediate code changes, but later implementation should align with these boundaries.

### WorldConfig

World configuration should expose explicit side-pad tiles.

Recommended direction:

- Keep lane tiles non-placeable.
- Mark side-pad tiles separately from blocked tiles.
- Prefer a placement-specific zone such as `placement_pad` if `side_pocket` becomes too broad.

### PlacementConfig

Placement configuration should eventually include:

- Structure id.
- Display name.
- Cost or cost band.
- Template/model name.
- Phase availability.
- Placement zone requirement.
- Structure cap participation.
- Repair eligibility.

### PlacementContext

Placement validation should remain server-authoritative.

Required validation:

- Run state is `Prep`.
- Structure id exists.
- Tile exists.
- Tile is a side pad/placement pad.
- Tile is unoccupied.
- Player has enough Energy.
- Structure cap is not exceeded.

### Combat And Targeting

Future combat implementation should treat structure effects as server-authoritative.

Client responsibilities should be limited to:

- Preview ghost.
- Placement range display.
- Error feedback.
- Placement confirmation.
- VFX/SFX presentation.

## Test Scenarios

### Readability

- A first-time player can identify valid pads before placing anything.
- The player understands why lane tiles are not valid.
- Preview feedback distinguishes valid, blocked, occupied, and unaffordable placements.

### Phase 2 Slice

- Player places Sentry Turret during Prep.
- Sentry Turret changes the outcome of a basic wave.
- Player cannot place during Wave state.
- Player cannot place on occupied pads.
- Player can complete a null or basic run without placement soft-locks.

### Roster Counterplay

- Swarm-heavy pressure rewards Stasis Field or Arc Pylon over Sentry-only stacking.
- Tank-heavy pressure exposes the weakness of Arc Pylon.
- Bulwark Projector stabilizes a mistake but does not win alone.
- Relay Beacon is not implemented until commander/summon rules are stable.

### Economy

- Structure spending competes with commander/summon Energy needs.
- Repair, if enabled, competes with new builds.
- Selling, if enabled later, cannot create an Energy-positive loop.

### Anti-Exploit

- Static defenses cannot create a zero-interaction infinite stall.
- Structure caps prevent unlimited pad abuse.
- Server rejects malformed client placement requests.
- Server rejects valid-looking requests that target illegal tiles.

## Assumptions

- Commander kit details are being handled separately.
- Relay Beacon remains intent-only until commander/summon design is locked.
- Exact costs, DPS, ranges, HP, cooldowns, and targeting rules are deferred.
- Side pads are the canonical V1 placement model.
- Phase 2 should implement only one clear structure before expanding the roster.
- `docs/GDD.md` will be updated separately after this plan is accepted.

