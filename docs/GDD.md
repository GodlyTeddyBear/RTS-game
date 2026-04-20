# Game Design Document (GDD)

**Working title:** RTS (wave defense)  
**Platform:** Roblox  
**Status:** Pre-production — design spine locked; systems TBD  
**Owner:** (you)  
**Last updated:** 2026-04-20  

---

## 1. Elevator pitch

A **sci-fi hybrid RTS wave-defense** game: you are a **summoner commander** on a **single lane**, spending **resources** to place defenses, craft stronger buildings, deploy summons, and survive escalating waves. **If the commander dies, the run ends.** After the main scripted climax, the run enters **endless waves with escalating mutators** while you chase **score** until you eventually fall.

---

## 2. Design pillars

These are non-negotiable filters for features, art scope, and UI.

1. **Tactical clarity** — Threats and mistakes are readable; deaths feel attributable.
2. **Meaningful prep** — Short windows between waves force real decisions, not idle time.
3. **Escalating adaptation** — Pressure rises through **new problems** (roles, mutators), not only bigger numbers.
4. **Score integrity** — Scoring rewards skill expression and risk; exploits are treated as bugs.

---

## 3. Target experience

| Dimension | Target |
|-----------|--------|
| Primary mode | **Solo** at launch |
| Co-op | **Phase 2** — same core systems, documented constraints only for now |
| Session shape | ~**20–30 minutes** to peak pressure; **endless + mutators** after climax |
| Narrative | **Systems-first** — minimal flavor text; no story-driven mission structure in v1 |
| Fantasy | **Summoner / tactician** commander |

---

## 4. Core loop (per run)

High level:

1. **Prep** — Spend resource, place/repair structures, set summons, position commander.
2. **Wave** — Enemies advance on the lane; player uses abilities, summons, and micro.
3. **Resolution** — Wave clears; short breather; **score events** tallied (see §8).
4. **Upgrade choice** — Pick from offered upgrades / tech (exact cadence TBD).
5. Repeat until **scripted climax** (boss or final scripted beat).
6. **Endless** — Waves continue with **stacking or rotating mutators** until commander death.
7. **Run end** — Final score, breakdown, unlock progress (meta TBD).

**Design intent:** Act A builds *identity* (what answers this enemy roster?). Act B (endless) tests *execution* under mutators and score pressure.

---

## 5. Win, loss, and run outcome

| Outcome | Definition |
|---------|----------------|
| **Loss** | **Commander HP reaches zero** (no alternate lose condition in v1 unless playtests demand one). |
| **“Main arc complete”** | Survive the **scripted climax** (boss / final set piece — specifics TBD). |
| **Post-climax** | **Endless escalation** — mutator pressure increases over time or wave count. |
| **Success metric** | **Score** + personal bests; optional leaderboards later. |

**Open design question (resolve in playtests):** Do you show a discrete “Boss defeated” moment as a *milestone* while continuing the same run, or a soft chapter transition?

---

## 6. Commander (summoner / tactician)

**Role:** The commander is the **primary tactical lever**, not a passive observer.

**Design constraints:**

- Abilities should **change space control** (zones, walls, slows, redirects) and **threat routing** (pull, taunt, bait summons).
- Avoid “win button” summons that erase encounter design; summons should create **new positioning puzzles** for the player.
- Commander fragility is a feature: **high agency + lethal mistake potential** must stay balanced for fun, not frustration.

**Kit shape (placeholder — counts TBD):**

- 1 **mobility or escape** tool (or implicit dash tied to another ability).
- 2 **summon / deployable** tools with different answers (swarm vs elite, etc.).
- 1 **control / stabilization** tool (slow, stun, knockback, barrier).
- 1 **ultimate** on a long cooldown for spike moments.

---

## 6.1 Commander Kit (v0)

All numeric values are v0 placeholders — balance pass required after EconomyContext income rates are established.

| SlotKey | Ability | Energy Cost | Cooldown | What it does |
|---|---|---|---|---|
| Mobility | **Blink Step** | 15 | 10s | Instant teleport up to 18 studs. No damage. Offensive reposition or defensive escape. |
| SummonA | **Swarm Drones** | 20 | 18s | Deploy 5 fast low-HP drones that chase the nearest enemy. Despawn after 20s. Strong vs groups, weak vs armor. |
| SummonB | **Elite Guardian** | 45 | 25s | Summon one stationary high-HP guardian that holds position and attacks in melee range. Despawn after 30s. |
| Control | **Gravity Pulse** | 25 | 14s | Short-range pulse (~10 studs) knocks all nearby enemies back 8 studs and slows them 1.5s. No damage. |
| Ultimate | **Overcharge Field** | 70 | 55s | 1s channel (interruptible by damage), then 25-stud burst: stuns enemies 3s + moderate damage + allied structures/summons gain +50% attack speed for 8s. |

### Counterplay matrix

| Ability | Strong against | Weak against | Mutator counter |
|---|---|---|---|
| Blink Step | Breakthrough enemies | — (pure utility) | "Rooted" — disables teleport |
| Swarm Drones | Swarm / low-HP groups | Armored / tank roles | "Drone Scrambler" — 50% damage |
| Elite Guardian | Mid-wave choke creation | Disruptor / ranged kiting | "Taunt Immunity" — summons ignored |
| Gravity Pulse | Dense groups, lane resets | Fast / spread formations | "Heavy" — knockback resisted |
| Overcharge Field | Clustered waves + structure synergy | Spread formations | "EMP Shielded" — stun immunity |

### Open questions

1. Is the Overcharge Field channel interruptible by damage? **Recommendation:** Yes — reinforces fragility.
2. Can Blink Step be used while channeling? **Recommendation:** No — channel locks movement.
3. Do Swarm Drones target nearest or lowest-HP enemy? **Recommendation:** Nearest for v1.
4. Does Elite Guardian block enemy pathing or pass-through? **Recommendation:** Pass-through for Phase 0; revisit in Phase 1.

---

## 7. Economy

**Multiple resource types.** Energy is the primary action resource; zone resources are the crafting/building economy.

### Resource types

- **Energy** — primary action resource. Spent on ability use, summon charges, placing structures, and repairs.
- **Zone resources** (names TBD — e.g. Metal, Crystals) — produced passively by extraction buildings placed on side-pocket tiles. Each zone type produces a distinct resource. Spent on crafting new building types and upgrading existing buildings.

### Income sources

1. **Passive extraction** — resource buildings placed on side-pocket tiles generate their zone resource over time.
2. **Enemy drops** — enemies drop resource pickups on death; nearby buildings or the commander collect them.
3. **Wave clear bonus** — TBD; maps to Efficiency score pillar.

### Sinks

| Sink | Resource |
|---|---|
| Place new structure | Energy |
| Ability use / summon charge | Energy |
| Repair structure | Energy |
| Craft new building type | Zone resource(s) |
| Upgrade existing building | Zone resource(s) |

### Design goals

- Every spend is a visible tradeoff: **action economy (Energy) vs build economy (zone resources) vs tempo (upgrade now vs hold)**.
- Sinks must stay legible — player always knows what they are spending and why.
- Resource buildings on zone tiles are high-value targets; enemy roles that attack buildings create genuine comeback tension when a resource building is lost.

### Anti-snowball

- Soft resource cap with overflow waste (prevents stockpile turtling).
- Resource buildings destroyed by enemies drop a portion of stored resources as pickups — recovery tension, not hard loss.
- Mutators can target resource buildings specifically (e.g. "Extractor Disruption" — buildings produce 50% for one wave).

### Open questions

- Resource type names — resolve before Structure roster section.
- How many distinct zone resource types in v1? Recommendation: 2–3 max.
- Do enemy drops produce zone-specific resources or a universal scrap? Recommendation: universal scrap convertible at a small tax.
- Is there a per-resource inventory cap or a shared total cap?

---

## 7.1 Crafting

**Crafting is Prep-phase only.** No placement or crafting during Wave phase.

### Two crafting operations

1. **Unlock + place new building type** — spend zone resources from inventory during Prep; building becomes available in the placement palette; commander places it on a valid tile.
2. **Upgrade existing placed building** — select a placed building during Prep; spend zone resources to upgrade it to a stronger tier in place; maximum 3 tiers (v1 placeholder).

### Design constraints

- Crafting menu is always fully readable — no hidden recipes. Player always sees what is available and what resources are missing (Tactical clarity pillar).
- Building roster and recipe table are TBD — drafted in §X "Structure roster".
- Higher tiers should change behavior, not only increase stats, where possible (Escalating adaptation pillar).
- All crafting locked during Wave phase — decisions must be made during Prep.

---

## 8. Scoring (survival + score)

Because the run continues into endless, **score** is the primary long-term goal.

**Suggested score pillars** (pick names you like; keep exactly three for clarity):

1. **Efficiency** — Low waste (overbuilding penalty or upkeep tax TBD).
2. **Aggression** — Forward plays, fast clears, optional risk objectives.
3. **Control** — Crowd control chains, choke exploitation, “clean” waves.

**Anti-exploit principles (write into GDD early):**

- If a strategy is **zero interaction** and **monotonic** (only gets safer over time), it is probably a **scoring dead end** or should be **mutator-countered**.
- Score components should be **inspectable post-run** (“why did I gain/lose points here?”).

---

## 9. Map and encounter space

**v1:** **Single lane** with **zone-typed tiles** — side pockets are resource extraction points, not just placement pads.

### Zone types

| Zone | Purpose | Resource |
|---|---|---|
| `lane` | Combat space — enemies travel here | None |
| `side_pocket` | Off-lane placement pad — each has an assigned resource type | Zone-specific (e.g. Metal, Crystal) |
| `blocked` | Impassable — no placement | None |

**Map position is meaningful:** which side pockets you control determines which resources you can extract and therefore which buildings you can craft. Losing a side pocket to a building-targeting enemy role cuts off that crafting branch.

**Intent:** Maximum tactical density; minimal “where do I look?” fatigue.

---

## 10. Enemies and mutators

**Enemy philosophy:** **Roles over stats** — swarm, tank, disruptor, artillery, stealth, healer/buffer, etc. Exact roster TBD.

**Mutator philosophy (endless):**

- Mutators change **rules**, not only HP/damage: visibility, spawn rhythm, resistances, commander debuffs, structure disables.
- Rotation vs stacking TBD; design for **readability** first.

---

## 11. Meta progression (light touch in GDD until scoped)

Document intent only until you decide monetization and retention:

- Prefer **horizontal unlocks** (new options, mutators, commander modules) before raw vertical power.
- Anything that trivializes early waves undermines endless scoring; gate carefully.

---

## 12. Phase 2 — co-op (constraints only)

Design v1 so co-op does not require a rewrite:

- **Threat scaling** model reserved (per-player addends vs shared wave budget).
- **Resource model** reserved (shared pool vs split incomes).
- **Revive / bleed** rules reserved (commander death = run end may need a co-op exception later).

---

## 13. Non-goals (v1)

Explicitly out of scope unless you revise this document:

- Campaign VO, cinematic mission structure, lore-heavy progression.
- Multi-lane macro RTS complexity.
- PvP-focused balance.

---

## 14. Next GDD sections to draft (order)

1. Commander kit (abilities, cooldowns philosophy, threat ownership).
2. Structure roster + placement rules.
3. Enemy role matrix + introduction order.
4. Wave cadence to climax + endless mutator deck.
5. Score formula v0 + telemetry fields.
6. Onboarding / first-run tutorial beats.

---

## 15. Reverse prompting pack

**Definition:** You start from the **output artifact** you want, list **hard constraints**, and force the model to **self-check**. Use this to generate each GDD section without drift.

### 15.1 Universal prompt skeleton

```text
Role: Lead game designer for a Roblox sci-fi hybrid RTS wave defense.

Hard constraints (do not violate):
- Solo-first; co-op is phase 2 notes only.
- Single lane; commander death ends the run.
- Summoner commander; one primary resource.
- Post-climax: endless waves + escalating mutators until death.
- Systems-first; flavor text only; no plot missions.

Task: Write GDD section: "<SECTION TITLE>".

Output rules:
- Max 1 page, bullets only.
- Every bullet must be testable (how a designer verifies in playtest).

Include at end:
- 3 risks + mitigations
- 5 open questions
```

### 15.2 Section-by-section reverse prompt chain

Run these in order; paste the **previous section’s open questions** into the next prompt as “Known open items”.

| Step | Section title | Extra instructions |
|------|----------------|-------------------|
| 1 | Vision alignment | Include “non-goals” and “why Roblox” in 3 bullets max. |
| 2 | Core loop states | Name each state; max 90s player downtime between waves at target tuning. |
| 3 | Commander kit | No more than 4 active slots + 1 ultimate unless you revise pillars. |
| 4 | Economy sinks | List every sink; each must map to a pillar. |
| 5 | Enemy roles | Provide counterplay matrix; no numbers. |
| 6 | Mutator deck | 12 mutator ideas; each must change rules, not only stats. |
| 7 | Scoring | Define 3 score pillars + anti-exploit rules + post-run breakdown fields. |
| 8 | MVP scope | Table: In / Out / Later with one-line rationale each. |

### 15.3 “Red team” reverse prompt (after each section)

```text
You are a skeptical senior designer + speedrunner + exploit tester.

Challenge the last GDD section:
- Find 5 failure modes (boring, unclear, exploitable, snowball, unfair RNG).
- For each: minimal rule change that fixes it without new art.
- If a fix needs new art, mark it as content cost and propose a cheaper alternative.
```

### 15.4 “Roblox reality” reverse prompt

```text
You are a Roblox production engineer reviewing the GDD section for feasibility.

Flag:
- What must be server-authoritative vs client-presented.
- What creates perf risk (entity counts, pathfinding, VFX spam).
- What needs telemetry on day 1.

Do not propose implementation code; constraints only.
```

---

## 16. Revision log

| Date | Change |
|------|--------|
| 2026-04-19 | Initial spine from design conversation. |
| 2026-04-20 | Added §6.1 Commander Kit (v0) with 5 abilities and counterplay matrix. |
| 2026-04-20 | Revised §7 Economy — multiple resource types, zone extraction, enemy drops, crafting sinks. |
| 2026-04-20 | Added §7.1 Crafting — Prep-phase only, unlock+place and upgrade operations. |
| 2026-04-20 | Revised §9 Map — zone types now carry resource type; side pockets are extraction points. |
| 2026-04-20 | Revised §1 elevator pitch to reflect multi-resource economy. |
