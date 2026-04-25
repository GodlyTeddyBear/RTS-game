# Game Design Document (GDD)

**Working title:** RTS (wave defense)  
**Platform:** Roblox  
**Status:** Pre-production — design spine locked; systems TBD  
**Owner:** (you)  
**Last updated:** 2026-04-24  

---

## 1. Elevator pitch

A **sci-fi hybrid RTS wave-defense** game: you are a **summoner commander** on a **single lane**, collecting **resources** to place defenses, develop your economy, craft stronger buildings, deploy summons, and fight waves with **abilities**. **Enemies aim to destroy your base (command post); the run also ends if the commander dies.** After the main scripted climax, the run enters **endless waves with escalating mutators** while you chase **score** until you lose the base, the commander, or both.

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
| v1 product depth | **Waves, prep, base defense, develop economy**, then **endless + mutators** and **score** — all remain v1 scope (not optional pillars). |
| Narrative | **Systems-first** — minimal flavor text; no story-driven mission structure in v1 |
| Fantasy | **Summoner / tactician** commander |

### Onboarding (first run, v0)

**Target:** **Standard** — about **2–4 minutes** of guided beats; the player should complete **one** real **prep → wave** loop before normal play.

| Beat | Intent |
|------|--------|
| **Lane and goals** | Command post and commander both matter; if either’s HP hits **0**, the run ends. |
| **Prep** | Place or repair (as unlocked by the tutorial build); **no** crafting or unlock during **Wave** phase. |
| **Resource legend** | **Scrap** from kills, converted in **Prep**; **Ferrium / Ceren / Voltrite** from **side pockets** (see §7). |
| **One ability** | One success condition on **Gravity Pulse** or **Swarm Drones** (not the full kit). |
| **First wave** | Clear without blocking the UI; on fail, one targeted hint (e.g. **Siege** or **Extractor** icon if in build). |
| **Hand-off** | Player continues into normal **prep → wave** cadence with **reduced** hinting, not a escort to wave 10. |

**Comprehension pass (playtest):** after the first full loop, the player can name **at least one** of: **base (command post) HP pressure**, **commander HP loss**, or **losing a pocket / Extractor hurts crafting**.

---

## 4. Core loop (per run)

High level:

1. **Prep** — Spend resource, place/repair structures, set summons, position commander, reinforce **base** defense where relevant.
2. **Wave** — Enemies advance on the lane toward the **base**; player uses abilities, summons, and micro to stop them.
3. **Resolution** — Wave clears; rest window for **build and develop**; **score events** tallied (see §8).
4. **Upgrade choice** — Pick from offered upgrades / tech (exact cadence TBD).
5. Repeat until the **scripted climax** (v1: **wave 10** siege set piece; see §10.3) — not a bespoke boss fight.
6. **Endless** — Waves continue with **mutators** (see §10.4) until a **lose condition** is met (see §5).
7. **Run end** — Final score, breakdown, unlock progress (meta TBD).

**Design intent:** Act A builds *identity* (what answers this enemy roster?). Act B (endless) tests *execution* under mutators and score pressure.

---

## 5. Win, loss, and run outcome

| Outcome | Definition |
|---------|----------------|
| **Enemy design goal** | **Destroy the base** — the **command post** (see below) is the primary objective enemies pressure; encounter roles and pathing should support readable **base defense** pressure. |
| **Player run goal** | **Survive and develop** — grow income and structures between waves, use prep windows to build, and keep the **base** and **commander** in play. |
| **Loss (base)** | **Command post (base) HP reaches zero** — the run ends. |
| **Loss (commander)** | **Commander HP reaches zero** — the run ends. Both loss paths are in v1 so mistakes in the field stay lethal even when the base is healthy. |
| **“Main arc complete”** | Survive the **scripted climax** — v1: **wave 10** (see §10.3), **siege** set piece, **no bespoke boss AI**. |
| **Post-climax** | **Endless escalation** — mutator pairs rotate (see §10.4) as wave count rises. |
| **Success metric** | **Score** + personal bests; optional leaderboards later. |

### Base (command post)

- **What it is:** A designated **base** structure (command post) with its own HP, placed at a fixed **lane anchor** (see §9). It is the **intended** target of enemy win pressure — “defend the base” is the headline defense goal.
- **v1 fail state (locked):** Run ends on **base destroyed** *or* **commander dead**; both are valid, independent lose conditions.
- **AI intent:** Enemies and wave scripts should create **legible** pressure on the **base** where possible, without removing optional pressure on the commander, buildings, and side pockets.

**Milestone (v1):** After the set piece, show a discrete **“Climax surmounted”** moment (flavor string TBD) while **continuing the same run** into endless. There is no **boss defeat** event in v1 (no boss encounter).

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

### v1 defaults (locked)

1. Overcharge Field channel is **interruptible by damage**.
2. Blink Step **cannot** be used while Overcharge Field is channeling.
3. Swarm Drones target the **nearest enemy**.
4. Elite Guardian uses **pass-through pathing** (non-blocking) for Phase 0; revisit in Phase 1 pathing work.

---

## 7. Economy

**Multiple resource types.** Energy is the primary action resource; zone resources are the crafting/building economy.

### Resource types

- **Energy** — primary action resource. Spent on ability use, summon charges, **placing** structures, and **repairs**.
- **Zone resources (v1 — three types)** — produced passively by **Extractors** (or equivalent) on **side-pocket** tiles. Spent to **unlock** new building types in the prep palette and to **upgrade** placed buildings. Types:
  - **Ferrium** — “chassis / hard defense” tree (turrets, hard structures).
  - **Ceren** — “field / control” tree (slows, zones, control-adjacent buildings).
  - **Voltrite** — “high-energy / burst / AOE” tree (clump damage, high-impact effects).
- **Scrap** — **universal** combat pickup from kills and related wave income. **Not** a fourth lane resource: Scrap is **converted in Prep** into Ferrium, Ceren, or Voltrite (see **Scrap and conversion**).

### Scrap and conversion (v0)

- Conversion happens **only in Prep** (Tactical clarity). Default UX: a single **convert** action (exact UI TBD) with **10% tax** (e.g. **100 Scrap → 90** of the chosen type; floor the loss so numbers stay integer-clean in UI).
- Tuning: tax can move to 15–20% or move behind a **structure** in a later build — document if changed.

### Soft caps (v0, tuning placeholders)

- **Ferrium, Ceren, Voltrite** each have the **same** per-type cap (e.g. **200** at baseline; tune in economy systems).
- **Scrap** has a separate cap (e.g. **150**).
- **Overflow:** income past cap is **wasted**; waste is a valid hook for **Efficiency** score (see §8).

### Income sources

1. **Passive extraction** — buildings on `side_pocket` tiles generate **Ferrium**, **Ceren**, or **Voltrite** per pocket’s assigned type.
2. **Enemy drops (Scrap)** — enemies and related clear rules grant **Scrap** pickups; nearby **structures** or the **commander** collect (exact pickup rules: engineering).
3. **Wave clear bonus** — TBD; should map to **Efficiency** (and possibly **Aggression** if time-based); finalize with score v0 in §8.

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
- Mutators can target resource buildings specifically (e.g. **Extractor Siphon** — buildings produce 50% for one wave; see §10.4).

### Open questions (remaining)

- Exact **income and costs** and **Scrap** spawn curve — **Economy** owner + tuning, not a GDD block.
- Whether conversion **tax** is global or can be temporarily raised by a mutator (see **Reclaim Tax** in §10.4) — v1: yes, allowed in endless.

---

## 7.1 Crafting

**Crafting is Prep-phase only.** No placement or crafting during Wave phase.

### Two crafting operations

1. **Unlock + place new building type** — spend zone resources from inventory during Prep; building becomes available in the placement palette; commander places it on a valid tile.
2. **Upgrade existing placed building** — select a placed building during Prep; spend zone resources to upgrade it to a stronger tier in place; maximum 3 tiers (v1 placeholder).

### Design constraints

- Crafting menu is always fully readable — no hidden recipes. Player always sees what is available and what resources are missing (Tactical clarity pillar).
- Building roster and recipe table: **§7.2** (v0; numbers are tuning placeholders).
- Higher tiers should change behavior, not only increase stats, where possible (Escalating adaptation pillar).
- All crafting locked during Wave phase — decisions must be made during Prep.

---

## 7.2 Structure roster and recipes (v0)

**Definition:** A **structure** is a **prep-placed** building on a **valid tile**; **placing** and **repairs** spend **Energy**; **first unlock** and **tier upgrades** spend **Ferrium / Ceren / Voltrite** (see recipe bias below). **Max 3 tiers** per building (v1 placeholder).

**Placement rules (v0):** Valid only in **RunPrep**; tile must be an allowed **side pocket** (or other authored pad) per structure type; **unoccupied**; type exists in roster; **Energy** to place. **Not** in **RunCombat** (same as §7.1). Exact collision / footprint in implementation.

| Structure | Job | **Phase target** (production gate) | Recipe bias (unlock / upgrade) |
|-----------|-----|------------------------------------|---------------------------------|
| **Sentry Turret** | Reliable **single-target** lane DPS. | **Phase 2** vertical slice | **Ferrium**-heavy. |
| **Stasis Field** | **Control** projected onto the lane (slow/zone) from a side pad. | **Phase 3** | **Ceren**-heavy; some **Ferrium** for mount. |
| **Arc Pylon** | **AOE / clump** damage (chain or splash) — best vs dense waves. | **Phase 3** | **Voltrite**-heavy; **Ferrium** for mounting. |
| **Bulwark Projector** | **Stabilization** (barrier, absorb, or short “hold” field — pick one in implementation) — buys time, must not perma-block the lane. | **Phase 3** | **Ferrium + Ceren** (mixed). |
| **Relay Beacon** | **Summon / ability tempo** support for the commander; must not be a flat “+10% all stats” by default. | **Phase 4+** (after kit lock) | **Voltrite + Ceren** (tuning). |

**Design intent:** Tiers should **change behavior** where possible, not only numbers (**Escalating adaptation**). Example pattern: Sentry T2 = priority rule or small profile change; Sentry T3 = timed **overburst** (example only).

**Numeric costs (v0):** Use explicit placeholder tables in a tuning sheet; GDD only locks **resource bias** and **which phase** a structure must land by. *Phase 2 slice* uses **Sentry Turret** only; other structures are content expansion, not a requirement to “ship all five” in a single phase.

**Alignment with archive:** A longer placement/write-up lived in the archive plan; this section is the **GDD** truth. If the archive conflicts on **one primary resource** or economy shape, this document wins.

---

## 8. Scoring (survival + score)

Because the run continues into endless, **score** is the primary long-term goal.

**Score pillars (v1 — keep exactly these three names):**

1. **Efficiency** — **Low waste** (capped/overflowed resources, overspend on static defense when wave pressure was solvable, Extractor/structure loss where avoidable, Scrap conversion under pressure).
2. **Aggression** — **Tempo and risk** (fast **wave** resolution, forward commander moments that worked, **optional** risk objectives if offered by the run).
3. **Control** — **Lane governance** (CC chains, choke exploitation, “clean” waves, mutator-appropriate play).

**v0 design bias (tuning default):** **Aggression** has the **largest marginal weight** for skilled play; **Efficiency** and **Control** stay **non-zero** so turtling and no-interaction strats are not the only answer.

### Score formula (v0)

- **Formulas, coefficients, and per-event weights** are **TBD in tuning** — owned by design + **Scoring** + economy baselines. This GDD locks **pillar definitions**, **anti-exploit**, and **post-run** fields, not the math.
- **Server-authoritative** event stream only (see [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md) security row).

**Anti-exploit principles (v1):**

- If a strategy is **zero interaction** and **monotonic** (only gets safer over time), it is a **scoring dead end** or should be **mutator-countered**.
- Every pillar contribution should be **inspectable** post-run.
- “Bank forever” and **unbounded** stockpiles are pre-empted by **soft caps and overflow** (see §7).

### Post-run breakdown (v0) — what the player can inspect

**Implementation** field names are suggestions; at least this **informational** level must be answerable in UI.

- **By pillar:** points (or subtotal) for **Efficiency / Aggression / Control** and **list of top 3** positive and negative drivers each.
- **When useful:** per-wave (or per-segment) **time to clear**; **wasted** resources; **Scrap** lost to cap; **structure / command post / Extractor** damage taken (if tracked).
- **Endless mutators:** which mutators were **active** in which segments (or waves), so odd scores are not mysterious.

**Telemetry (design-level, day-1 friendly):** pillar event counts, run length, max wave, climax reached (Y/N), endless entered (Y/N), active mutator ids per wave, score revision id (if hotfixes), and **anomaly** flags for score audits (e.g. zero Aggression in a 20+ wave run). Exact schema is engineering-owned.

---

## 9. Map and encounter space

**v1:** **Single lane** with **zone-typed tiles** — side pockets are resource extraction points, not just placement pads.

### Zone types

| Zone | Purpose | Resource |
|---|---|---|
| `lane` | Combat space — enemies travel toward the **base** | None |
| `side_pocket` | Off-lane placement pad — each has an assigned resource type | **Ferrium**, **Ceren**, or **Voltrite** (one type per pocket) |
| `base_anchor` | **Command post (base)** — fixed placement for the one **base** structure; primary enemy objective; no resource generation | None |
| `blocked` | Impassable — no placement | None |

**Map position is meaningful:** which side pockets you control determines which resources you can extract and therefore which buildings you can craft. Losing a side pocket to a building-targeting enemy role cuts off that crafting branch. The **base** sits at a **base_anchor**; losing it **ends the run** (see §5).

**Intent:** Maximum tactical density; minimal “where do I look?” fatigue.

---

## 10. Enemies and mutators

**Enemy philosophy:** **Roles over stats** — v1 **teaching spine** uses the six roles below. Wave composition should create varied answers while keeping **threat to the base** and **surgical** pressure on **Extractors** (where used) **legible**.

### 10.1 Role matrix and counters (v0)

| Role | What it is | Failure mode (player) | Common answers | Notes |
|------|------------|------------------------|----------------|--------|
| **Swarm** | Many low individual threats, flood timing | Drowned in minions, split focus | Sentry, Swarm Drones, AOE, **Gravity Pulse**, Stasis (when in build) | **Teaches** coverage and DPS. |
| **Bruiser** | **Tank**-style sustained HP, demands sustained answer | Turret or commander attention sinks | Sustained DPS, **Elite Guardian**, focus fire | Taught after Swarm. |
| **Disruptor** | Breaks **rhythm** (daze, slip, short disables) | Your **turrets / commander** don’t get value at the moment you need them | Stabilize with Bulwark/Stasis, **re-prep** plan | Taught as “unfair if ignored.” |
| **Artillery** | Ranged / arc pressure — **geometry** and reach | **Open commander** in bad lanes | **Blink**, pre-placed control, lane denial | Taught with lane angles. |
| **Siege** | **Pushes the command post and/or Extractors** | Ignores the **base game** of pockets | Repairs, **protect** pockets, Stasis, Bulwark, Energy saves | Drives **climax**; must read as *base* pressure. |
| **Elite (skirmisher)** | **Duel** pressure on the **commander** or on gaps in defense | Greed, bad spacing, panic | **Bait** with summons, **Blink**, don’t yolo | **Lethal mistakes** in the field stay real. |

**Verify:** the **first** wave that **spotlights** a new role has **one** job the **brief or tip** can name without a paragraph of text.

### 10.2 Introduction order (teaching, v0)

1. **Swarm** (early; waves **1–2** in a teaching build).  
2. **Bruiser**.  
3. **Disruptor** *or* **Artillery** first (per map, **one** new idea that wave, not both at full complexity).  
4. The other of (3).  
5. **Siege** (before the climax) — at least one **dedicated** teaching exposure.  
6. **Elite** in **doses** — must not **steal** every other lesson the same wave.

*Exact wave numbers* outside the slice are **tuning**; the **order** is design-locked for readability.

### 10.3 Wave cadence, wave 9 preview, and wave 10 climax (v0)

- **Waves 1–6 (Phase 2 vertical slice):** prove **loop** and **Sentry Turret** + one summon line. Roles can be **Swarm**-heavy with a **Bruiser** tease; full roster is **not** required to pass Phase 2.  
- **Waves 7–9 (Phase 3+):** roll in **Disruptor**, **Artillery**, and **trained Siege** pressure. **Wave 9 (default):** **siege preview** — first **serious** base/Extractor pressure, **less intense** than wave 10.  
- **Wave 10 (v1) — set piece, not a boss:** **Siege**-themed **climax** — peak **base and Extractor** pressure; at least one **Disruptor** or **Artillery** layer so the wave is not solved by **Sentry** alone. **No bespoke boss** AI, **no** separate boss encounter — a **scripted** composition + one clear **milestone** banner (see §5).  
- **After wave 10:** handoff to **endless** and **§10.4** mutator rules.  
*Wave count, spawn budgets, and internal elite density — **Encounter** owner and tuning.*

### 10.4 Endless — mutator policy and deck (v0)

**Policy (readability / “hard but fair”):**

- **At most 2** mutators **active** at a time.  
- **Rotation:** e.g. every **N** waves, **at least one** slot is **cycled** to a new mutator (**N** is **tuning**, suggest **3–5** for first read tests). Stacking is **capped** by the **2**-slot rule — not unbounded staccato.  
- **UI:** the player always sees **both** active mutator **names** and a **one-sentence** rule each (Phase 4 deliverable).  
- **Tone v1:** **hard but fair** — avoid **untelegraphed** combos; difficulty comes from **rule clarity**, not gotchas.

| Mutator | Rule (v0) | Notes |
|---------|-----------|--------|
| **No Step** | **Blink Step** is **disabled** for this wave. | Aligns with “Rooted” in §6.1 matrix. |
| **Scramble Drones** | **Swarm Drones** deal **50%** damage. | |
| **Gravity Heavy** | **Gravity Pulse** **knockback and slow** are **half** as effective. | |
| **Stun Leak** | **Overcharge Field** **stun** is **50%** shorter; attack-speed buff to allies unchanged. | |
| **Extractor Siphon** | All **Extractors** produce **50%** for this wave. | |
| **Rationing** | All **ability Energy costs +10%** (tune 10–15%). | |
| **Thin Prep** | The **next Prep** is **3 seconds** shorter (or **−10%** duration — **pick one** in tuning, don’t double-apply). | |
| **Shorter Reach** | **Defensive** structures have **~90%** of normal **max range** for this wave. | |
| **Shuttered Targeting** | Each **defensive** structure has a **2s** **warm-up** before the **first** shot **this wave** (tune 1–2s if two mutators feel cruel). | Telegraphed in UI. |
| **Reclaim Tax** | **Next Prep** only: **Scrap** conversion **tax** increases (e.g. **10%** → **20%**); announce **before** that Prep **ends** in endless. | Stacks design with §7. |
| **Pulse Tax** | **Gravity Pulse** **cooldown +3s** this wave. | |
| **Swarm Resurgence** | At the **~70%** mark of **wave** elapsed time, a **second Swarm** batch spawns (fixed, **not** random). | **Aggression** pressure. |

**Open (tuning):** additional mutator ideas, exact **N** for rotation, and whether **Reclaim Tax** and **Extractor Siphon** can appear in the same pair in ship builds.

---

## 11. Meta progression (light touch in GDD until scoped)

Document intent only until you decide monetization and retention:

- Prefer **horizontal unlocks** (new options, mutators, commander modules) before raw vertical power.
- Anything that trivializes early waves undermines endless scoring; gate carefully.
- **v1 depth (default):** a **defined set** of unlocks and **earn rules** (currency, achievements, score gates — product); **fallback** from [GamePlan/Development-Phases.md](../GamePlan/Development-Phases.md): **horizontal** options only; **no** flat **+damage** / **+HP** on everything as the default reward.

---

## 12. Phase 2 — co-op (constraints only)

Design v1 so co-op does not require a rewrite:

- **Threat scaling** model reserved (per-player addends vs shared wave budget).
- **Resource model** reserved (shared pool vs split incomes).
- **Revive / bleed** rules reserved (base or commander **loss = run end** in solo may need a co-op exception later, e.g. revive window).

---

## 13. Non-goals (v1)

Explicitly out of scope unless you revise this document:

- Campaign VO, cinematic mission structure, lore-heavy progression.
- Multi-lane macro RTS complexity.
- PvP-focused balance.

---

## 14. Next GDD sections to draft (order)

**Completed in this document (v0):** §6.1 Commander kit; §7 economy (Scrap + three zone types); §7.2 structure roster; §8 scoring bias + inspectability + telemetry intent; §10 roles, waves 9–10, mutator deck; §3 onboarding beats.

**Still to tighten (tuning / content pass):**

1. **Numeric** balance — Energy, Scrap, Ferrium/Ceren/Voltrite costs, caps, wave spawn counts, mutator **N** and **pairing** bans.  
2. **Score** — exact **coefficients** and per-event weights after **EconomyContext** baselines.  
3. **Wave script** — authored table per map (Phase 2: 6 waves; full arc: through **wave 10** then handoff).  
4. **Extra mutators** — expand pool beyond 12 if needed; **leaderboard** exploit thresholds (see `Development-Phases`).

---

## 15. Reverse prompting pack

**Definition:** You start from the **output artifact** you want, list **hard constraints**, and force the model to **self-check**. Use this to generate each GDD section without drift.

### 15.1 Universal prompt skeleton

```text
Role: Lead game designer for a Roblox sci-fi hybrid RTS wave defense.

Hard constraints (do not violate):
- Solo-first; co-op is phase 2 notes only.
- Single lane; run ends if the **base (command post)** is destroyed **or** the **commander** dies.
- Summoner commander; **multiple resource types** (Energy + zone resources) as in §7.
- **Enemy pressure** should readable threaten the **base**; v1 has **waves, prep, develop**, then post-climax **endless** + **mutators** and **score**.
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
| 2026-04-24 | Aligned v1 with **base (command post)** and dual lose conditions; **survive and develop** + enemy **base** goal; `base_anchor` in §9; v1 scope explicitly retains endless/mutators/score; updated reverse-prompt constraints. |
| 2026-04-24 | **Co-draft applied:** **Ferrium / Ceren / Voltrite**, **Scrap** + conversion + caps; §7.2 **structure roster**; §10 **six roles**, **wave 9** siege preview, **wave 10** siege set piece (no boss AI), **12** mutators + **2**-active policy; §8 **Aggression** bias + breakdown/telemetry intent; §3 **onboarding**; §5 milestone; §11 meta fallback. |
