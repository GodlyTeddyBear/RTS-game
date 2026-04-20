# Game Design Document (GDD)

**Working title:** RTS (wave defense)  
**Platform:** Roblox  
**Status:** Pre-production — design spine locked; systems TBD  
**Owner:** (you)  
**Last updated:** 2026-04-19  

---

## 1. Elevator pitch

A **sci-fi hybrid RTS wave-defense** game: you are a **summoner commander** on a **single lane**, spending **one resource** to place defenses, deploy summons, and survive escalating waves. **If the commander dies, the run ends.** After the main scripted climax, the run enters **endless waves with escalating mutators** while you chase **score** until you eventually fall.

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

## 7. Economy

**v1 rule:** **One primary resource** (working name: **Energy**).

**Design goals:**

- Every spend is a visible tradeoff: **defense vs tempo vs commander safety**.
- Sinks must stay legible: structures, summon charges, repairs, key upgrades — not five parallel currencies.

**Open questions:**

- Income sources: wave clear bonus, passive extractor, last-hits, combo rewards?
- Anti-snowball: what prevents perfect turtling from trivializing endless?

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

**v1:** **Single lane** with optional **side pockets / pads** for placement depth (not multi-lane macro).

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
