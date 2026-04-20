# Chapter 3 - Brewery prep & potion execution

**Status:** Scoped for MVP implementation.

---

## Chapter intent

Chapter 3 proves **consumables as a core strategy loop**: the player uses the new **Brewery** to produce potions, then applies those potions in expeditions through meaningful loadout and timing decisions. This chapter is not about broad alchemy depth. It is about making **brew -> stock -> bring -> use** feel essential alongside existing gear prep.

The chapter has two connected parts:

1. **Brewery production loop** (new lot, brewer worker, potion output).
2. **Expedition potion utilization loop** (pre-run loadout + in-run usage decisions).

---

## Locked decisions

- Chapter 3 is centered on the **Brewery**.
- Chapter 3 has two explicit focuses:
  - Brewing potions.
  - Utilizing potions during expeditions.
- **`BrewKettle` is the only required building** for Chapter 3 MVP progression.
- No additional building is required to craft the first recommended potion kit.
- Chapter 3 should reinforce prep agency, not remove chapter 2 stakes.
- Potion usage is a strategic layer (limited slots/cooldowns), not an unlimited spam system.

---

## In-scope features (MVP)

### Focus A - Brewery production (first)

- Unlock beat for Brewery after chapter 2 completion.
- Place and activate **`BrewKettle`** as chapter entry action.
- Introduce the **brewer** worker tied to the Brewery lot.
- Brewing supports both:
  - Manual player craft at brewery UI.
  - Brewer assignment/orders.
- Manual and worker channels feed the same shared inventory.
- Brewer only takes recipes that are currently eligible (same rule as manual brewing).
- Starter potion set (3-4 recipes) with simple, readable effects:
  - Sustain potion (small heal or short regen).
  - Defense potion (brief durability window).
  - Escape/tempo potion (retreat reliability or movement utility).
  - Optional risk/reward potion (small upside with clear downside).
- First useful potion set is craftable from chapter 1/2 economy-compatible inputs (no expedition-rare dependency).

### Focus B - Potion usage in expedition (second)

- Expedition prep includes consumable loadout selection.
- Adventurer has limited potion slots (small count so tradeoffs are meaningful).
- Potion effects are short, explicit, and surfaced clearly in UI.
- Potions can be consumed in-run with cooldown/use rules to prevent spam.
- Guide teaches when and why to use potions (not just that they exist).
- Outcome handling integrates potion economy cleanly:
  - Used potions are consumed.
  - Unused carried potions resolve by configured expedition outcome rules.

---

## Brewer role definition (MVP)

- **Core function:** convert ingredients into expedition consumables.
- **Parity rule:** recipe eligibility is shared between manual brewing and brewer orders.
- **Queue behavior:** brewer runs one order at a time; batch/throughput tuning is data-driven.
- **Stock support:** brewer can be assigned to maintain baseline stock for starter potions.
- **No overreach in chapter 3:** brewer does not introduce advanced optimization systems yet (no complex catalyst/failure minigame).

---

## Building requirements for chapter 3

### Required building

- **`BrewKettle`**
  - Required for chapter progression in chapter 3.
  - Unlocks all chapter-3-critical starter potion recipes.
  - Must support both manual brewing and brewer assignments.

### Explicit non-requirements for MVP

- No second mandatory brewery structure in chapter 3.
- No mandatory fermentation chain for chapter completion.
- Optional future buildings may exist in data but cannot block chapter-3-complete path.

---

## Out of scope (chapter 3 MVP)

- Deep alchemy tech tree and long potion branches.
- Complex buff stacking interactions.
- Large ingredient rarity ecosystem.
- Multi-step brewing minigames or quality simulation.
- Chapter-wide dependency on additional brewery buildings beyond **`BrewKettle`**.
- Broad expedition biome expansion unrelated to potion loop proof.

---

## Outcome rules

These rules apply once the player starts expeditions using chapter 3 potion systems.

- **Victory**
  - Run resolves successfully.
  - Potion usage should feel materially useful to success.
  - Chapter progression increments toward chapter 3 completion objective.
- **Defeat**
  - Existing chapter 2 stakes still apply.
  - Any potion consumed during the run is spent.
  - Carried potion loss follows expedition loss policy.
- **Fled**
  - Retreat resolves without chapter completion.
  - Consumed potions remain spent.
  - Remaining carried potion resolution follows flee policy.

---

## Guide NPC behavior in this chapter

Guide acts as a **tactical prep mentor**: teach consumables as deliberate run tools.

### Guidance beats

1. **Brewery intro beat**
   - Introduce Brewery and `BrewKettle`.
   - Prompt first brew and explain that potions join shared inventory.
2. **Brewer intro beat**
   - Introduce brewer as parallel production path.
   - Prompt first assignment on a starter potion.
3. **Loadout beat**
   - Prompt player to equip potions before launch.
   - Explain slot limits briefly.
4. **In-run reminder beat**
   - Encourage use at clear moments (low health, danger spike, retreat window).
5. **Outcome beat**
   - `Victory`: reinforce good timing and prep.
   - `Defeat`: reinforce rebuild + restock loop.
   - `Fled`: reinforce tactical retreat and re-prep.

### Messaging rules

- Keep lines short (1-2 sentences).
- Always include the next actionable step.
- Name potion tradeoffs plainly; avoid hidden rules.

---

## Requirements checklist

### Focus A - Brewery production

- [ ] Brewery unlock and first `BrewKettle` placement are playable.
- [ ] Player can craft starter potions manually at Brewery.
- [ ] Brewer unlock/hire and first assignment are playable.
- [ ] Brewer and manual crafting share recipe eligibility rules.
- [ ] Starter potion set is craftable with **`BrewKettle` only**.
- [ ] Starter potion inputs are achievable from existing economy loops.

### Focus B - Expedition utilization

- [ ] Expedition prep supports potion loadout selection.
- [ ] Potion slot limits are enforced.
- [ ] Potions are usable in-run with anti-spam constraints (cooldown or equivalent).
- [ ] Effects are clearly communicated (what, how long, tradeoff if any).
- [ ] Outcome rules handle consumed/carried potions consistently.
- [ ] Chapter progression checks include real potion utilization, not unlock-only actions.

---

## Tuning guardrails (initial)

- First potion loop should be affordable and teachable quickly after chapter entry.
- `BrewKettle` should carry all chapter-critical recipes; extra buildings must not become hidden gates.
- Starter potion effects should be meaningful but not invalidate gear prep or expedition danger.
- Potion loadout choices should create tradeoffs, not mandatory one-true builds.
- Failure recovery should remain economic and strategic (rebuild/restock/retry), not protected by pity systems.
