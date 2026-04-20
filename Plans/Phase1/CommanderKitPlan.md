# Commander Kit — GDD Design Content (§6.1)

## Context

The GDD (§6) defines the commander as the primary tactical lever with a 5-slot kit:
1 mobility/escape, 2 summon/deployable, 1 control/stabilization, 1 ultimate.

The CommanderContextPlan already has full technical scaffolding but uses placeholder
values for all ability names, costs, and cooldowns. This plan fills those placeholders
with real design content grounded in the GDD's four pillars:
- **Tactical clarity** — threats readable, deaths attributable
- **Meaningful prep** — every spend is a real decision
- **Escalating adaptation** — new problems, not just bigger numbers
- **Score integrity** — skill expression rewarded

**Output:** A finalized ability table to append to `docs/GDD.md` as §6.1, and the
slot values that replace placeholders in `CommanderConfig.lua` when implemented.

---

## Design Constraints (from GDD)

- One resource: **Energy**. Every spend is defense vs tempo vs commander safety.
- Abilities must **change space control** or **threat routing** — not just deal damage.
- Summons must create **positioning puzzles**, not erase encounter design.
- Commander fragility is a feature — high agency + lethal mistake potential.
- Single lane with optional side pockets. No multi-lane macro.

---

## Proposed Kit

### Slot 1 — Mobility: **Blink Step**

**What it does:** The commander instantly teleports to a target position within a short
range (~18 studs). No animation delay. Can be used offensively (reposition to place a
summon) or defensively (escape a breakthrough enemy).

**Design intent:**
- Pure repositioning — deals no damage.
- Short range keeps it tactical; can't skip the entire lane.
- Creates risk decisions: use it aggressively to set up a summon, or save it as
  an escape hatch when a tank breaks the line.

**Pillar alignment:** Tactical clarity (readable escape window), Meaningful prep
(spending it early costs the escape safety net).

**Values:**
| Stat | Value |
|---|---|
| Energy cost | 15 |
| Cooldown | 10s |
| Teleport range | 18 studs |

**Mutator counter:** "Rooted" — disables Blink Step for one wave, forcing the
commander to rely on structures and summons for safety.

---

### Slot 2 — SummonA: **Swarm Drones**

**What it does:** Deploys a cluster of 5 small fast-moving drone units that chase the
nearest enemy on the lane. Each drone has low HP and low damage but they are fast and
overwhelming in numbers. They despawn after 20 seconds or when killed.

**Design intent:**
- "Swarm" answer per GDD §6 — best against groups of low-HP enemies.
- Weak against tank/armored roles — creates natural counterplay as enemy roster grows.
- Low cost = spammable during Wave phase; tradeoff is no lane-holding ability.
- Drones pull enemy attention forward, which can expose the commander if she follows.

**Pillar alignment:** Meaningful prep (low cost = frequent decision point), Escalating
adaptation (becomes less effective vs armored roles in later waves).

**Values:**
| Stat | Value |
|---|---|
| Energy cost | 20 |
| Cooldown | 18s |
| Drone count | 5 |
| Drone HP | 15 each (placeholder) |
| Drone damage | 3/hit (placeholder) |
| Duration | 20s or until killed |

**Mutator counter:** "Drone Scrambler" — drones deal 50% damage for the wave.

---

### Slot 3 — SummonB: **Elite Guardian**

**What it does:** Summons a single large guardian unit at the commander's current
position. High HP, moderate damage. Does NOT chase enemies — holds its position and
attacks anything within melee range. Despawns after 30 seconds.

**Design intent:**
- "Elite" answer per GDD §6 — contrasts with Swarm Drones: anchor vs aggressor.
- High cost forces genuine tradeoff: Guardian vs building a structure vs saving for Ultimate.
- Stationary nature makes placement decisions matter.
- Creates a temporary choke point mid-wave that structures can't fill.

**Pillar alignment:** Tactical clarity (readable hold-line), Meaningful prep (highest
regular spend, obvious decision weight).

**Values:**
| Stat | Value |
|---|---|
| Energy cost | 45 |
| Cooldown | 25s |
| Guardian HP | 200 (placeholder) |
| Guardian damage | 12/hit (placeholder) |
| Duration | 30s or until killed |

**Mutator counter:** "Taunt Immunity" — enemies ignore summons for one wave, forcing
the commander to use structures and abilities alone.

---

### Slot 4 — Control: **Gravity Pulse**

**What it does:** Fires a short-range pulse from the commander's position that knocks
all enemies within ~10 studs backward along the lane by ~8 studs. Deals no damage.
Affected enemies are briefly slowed (1.5s) after landing.

**Design intent:**
- Knockback + slow creates a repositioning window, not a damage spike.
- Short range means the commander must be in danger to use it — reinforces fragility.
- Interacts with structures: knocking enemies back into a tower's attack range is a
  high-skill play (scores Aggression + Control pillars simultaneously).
- Does not chain into a permanent stun loop — enemies resume after the slow expires.

**Pillar alignment:** Tactical clarity (readable effect), Score integrity (precise
positioning rewarded), Escalating adaptation (less effective vs fast/spread enemies).

**Values:**
| Stat | Value |
|---|---|
| Energy cost | 25 |
| Cooldown | 14s |
| Pulse radius | 10 studs |
| Knockback distance | 8 studs |
| Slow duration | 1.5s |

**Mutator counter:** "Heavy" — enemies resist knockback (reduced to 2 studs) for one wave.

---

### Slot 5 — Ultimate: **Overcharge Field**

**What it does:** The commander channels for 1 second, then releases a large pulse
(~25 stud radius) centered on herself. All enemies in range are stunned for 3 seconds
and take a one-time moderate damage hit. All allied structures and summons within range
gain +50% attack speed for 8 seconds.

**Design intent:**
- Dual effect (enemy stun + ally buff) rewards careful positioning near structures.
- 1-second channel creates a committed risk window — interruptible if the commander
  takes damage (reinforces fragility-as-feature).
- Structure buff creates Aggression scoring opportunities (faster clears = bonus score).
- Long cooldown means it defines a wave rather than dominating every wave.

**Pillar alignment:** All four pillars — readable effect, meaningful decision,
new pressure on use, skill-expressive positioning rewards score.

**Values:**
| Stat | Value |
|---|---|
| Energy cost | 70 |
| Cooldown | 55s |
| Channel time | 1s (interruptible by damage) |
| Stun radius | 25 studs |
| Stun duration | 3s |
| One-time damage | 40 (placeholder) |
| Ally buff | +50% attack speed, 8s |

**Mutator counter:** "EMP Shielded" — enemies immune to stun for one wave, removing
the defensive half of the ultimate and forcing it to be used for the ally buff only.

---

## Counterplay Matrix

| Ability | Strong against | Weak against | Mutator counter |
|---|---|---|---|
| Blink Step | Breakthrough enemies | — (pure utility) | "Rooted" — disables teleport |
| Swarm Drones | Swarm / low-HP groups | Armored / tank roles | "Drone Scrambler" — 50% damage |
| Elite Guardian | Mid-wave choke creation | Disruptor / ranged kiting | "Taunt Immunity" — summons ignored |
| Gravity Pulse | Dense groups, lane resets | Fast / spread formations | "Heavy" — knockback resisted |
| Overcharge Field | Clustered waves + structure synergy | Spread formations | "EMP Shielded" — stun immunity |

---

## Open Questions

1. **Is the Overcharge Field channel interruptible by damage?**
   Recommendation: Yes — interruptible. Reinforces fragility, punishes greedy use.
   Flag as playtest risk (may feel frustrating if enemies are too aggressive).

2. **Can Blink Step be used while channeling Overcharge Field?**
   Recommendation: No — channel locks movement. Simpler and more readable.

3. **Do Swarm Drones target nearest enemy or lowest-HP enemy?**
   Recommendation: Nearest for v1. Revisit if drones feel "dumb" in playtests.

4. **Does Elite Guardian block enemy pathing (physical barrier) or pass-through?**
   Recommendation: Pass-through for Phase 0 (no pathfinding complexity added).
   Revisit in Phase 1 enemy pathing work.

5. **All numeric values are v0 placeholders.** Balance pass required after
   EconomyContext income rates are established.

---

## CommanderConfig.lua Slot Table (replaces placeholders from CommanderContextPlan Step 2)

| SlotKey | DisplayName | EnergyCost | CooldownDuration |
|---|---|---|---|
| Mobility | Blink Step | 15 | 10 |
| SummonA | Swarm Drones | 20 | 18 |
| SummonB | Elite Guardian | 45 | 25 |
| Control | Gravity Pulse | 25 | 14 |
| Ultimate | Overcharge Field | 70 | 55 |

---

## Files to Update

| File | Action |
|---|---|
| `docs/GDD.md` | Append §6.1 — Commander Kit (v0) with kit table, counterplay matrix, open questions |
| `src/ReplicatedStorage/Contexts/Commander/Config/CommanderConfig.lua` | Use finalized slot values above (at implementation time) |

---

## Verification

- Every slot maps to exactly one GDD kit shape entry (no overlaps, no gaps).
- Every ability changes space control or threat routing — none are pure damage.
- No ability is zero-interaction or monotonic (channel creates risk; short-range pulse
  requires danger proximity; swarm drones are temporary).
- Every ability has at least one mutator counter in the counterplay matrix.
- Open questions enumerated with v1 defaults — no design decision deferred without a recommendation.
