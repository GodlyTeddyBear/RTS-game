# Chapter 2 — Gear up & first expedition

**Status:** Scoped for MVP implementation.

---

## Chapter intent

Chapter 2 proves **shared inventory → adventurer equipment → visible readiness**: the player uses guild shop outputs and the **one inventory, many jobs** model to outfit adventurers before serious risk. The **Forge** lot and **blacksmith** worker are the primary fiction for turning chapter 1 outputs into **equippable** gear (**smelt → forge craft → equip**).

The **first expedition** is the **capstone** of the chapter—where permadeath and gear loss land—not the only subject. This chapter is about proving that **prep then run** loop, not broadening content breadth.

---

## Locked decisions

- **First expedition** belongs in **chapter 2** (not chapter 1).
- Chapter 1 still ends with a **vague teaser** into chapter 2.
- **Chapter completion:** player achieves **one `Victory`** on an expedition.
- **Stakes timing:** **permadeath + gear loss are active immediately** from the first chapter 2 run.
- **Prep vs. launch:** There is **no hard gear gate** for starting a run. Getting geared is **taught and nudged** (guide + UX), not a blocking milestone—unless this decision changes later.
- **Building-gated recipes:** Forge recipes may require **specific placed buildings** on the lot (e.g. smelter, anvil, bellows—exact IDs live in implementation config). If a recipe is locked, the lock is **“cannot craft this yet,”** not **“cannot launch expedition.”**
- **Blacksmith parity:** A blacksmith may only **take orders / tick** recipes whose **building requirements are satisfied** on the player’s Forge (same eligibility as **manual** forge craft for that recipe—one rule, two channels).

---

## In-scope features (MVP)

### Focus A — Gearing up (first)

- Expedition unlock beat directly after chapter 1 smelter completion (unlocks staging; player can engage prep before first launch).
- Party prep flow: select adventurer and equip from shared inventory.
- Shop/craft-to-gear beats as needed so outfitting is a **real loop** (items the player can make or already have feed slots, not a hollow UI step).

#### Forge (zone + crafting)

- **Narrative role:** The Forge is where **semi-finished metal and other inputs become weapons and armor**—same **shared inventory** used for selling and equipping. The **smelter** (chapter 1 cap) already lives in this zone; chapter 2 teaches **smelt → forge craft → equip** as one readable chain.
- **Recipe emphasis for first-run prep** (pick what implementation highlights; all should be achievable **without expedition loot**):
  - **Basic iron kit** — weapon + chest crafted **directly from iron ore** (fast path to a real loadout).
  - **Smelter bridge** (optional teaching hop) — e.g. **plates from the smelter** feeding a **basic weapon** that needs refined metal, so ore → plate → gear is felt once.
  - **Light alternative** — e.g. **stone-leaning light chest** so players who weighted wood/ore differently in chapter 1 still have a chest option without mirroring the iron path only.
- **Forge UI:** Foreground **equippable** recipes (weapons and armor). **Materials** (charcoal, plates, etc.) stay discoverable but are not the main onboarding beat—**gear** is.
- **Building requirements (design rule):**
  - Extend the recipe model so **ingredients + required placed buildings** both gate a craft. Higher or specialized gear can require **Anvil**, **Bellows**, or other Forge-slot buildings in addition to the **Smelter** the player already placed to end chapter 1.
  - **Chapter 2 entry state:** At minimum, the player has the **Smelter** on the Forge lot. Curate the **first-run recommended kit** (weapon + chest) so it is craftable with **only buildings guaranteed at that moment**—unless the chapter intentionally adds a **very short** “place the anvil” (or similar) beat **before** the stakes primer; in that case, keep cost and step count small so it still reads as prep, not a second chapter-1 grind.
  - **Greyed recipes** in UI should show **which building** unlocks them (copy + icon), so the loop is “see goal → place/upgrade building → craft,” not guesswork.

#### Blacksmith (worker)

- **Introduce** the **Forge-role** worker (player-facing name: **blacksmith**): hire or unlock beat tied to the Forge lot.
- **First assignment** as tutorial: point them at an **automatable** starter weapon or armor recipe so **ticks feed the same inventory** used to equip—**manual crafting at the forge** and **blacksmith orders** should read as two ways to fill the same slots.
- **Building alignment:** Assignment UI (or server validation) only offers recipes **valid for current buildings**; if the player needs **Anvil II** for a sword line, the blacksmith cannot take that order until the building exists—same as manual craft.
- **If worker automation is not ready for MVP:** deliver **NPC + dialogue + pointer to forge recipes** only—no copy that promises passive crafting until the loop ships.

### Focus B — First expedition (second)

- One starter zone tuned for first success after basic preparation.
- Full outcome handling: **`Victory / Defeat / Fled`**.
- Chapter progression hook that marks chapter 2 complete only on first `Victory`.
- Guide follow-up lines for each outcome.

---

## Out of scope (chapter 2 MVP)

- Multiple zones and branching route structures.
- Deep class/skill trees.
- Safety nets, wipe compensation, or protection runs.
- Tight commission/rep coupling to expedition unlock flow.
- **Deep forge progression** as a chapter gate: full **steel-tier** weapon/armor trees, long accessory lines, and other **post–first victory** recipe breadth—not required to clear chapter 2.
- Documenting or implementing the **full** building × recipe matrix for every late-game item (belongs in data/config and long-term content planning, not chapter 2 MVP scope).

---

## Outcome rules

These apply once the player **chooses to launch** an expedition after (recommended) prep.

- **Victory**
  - Expedition succeeds.
  - Loot and rewards are granted.
  - If first `Victory`, chapter 2 is completed.
- **Defeat**
  - Adventurer dies permanently.
  - Equipped gear on that adventurer is lost.
  - Chapter does not complete.
- **Fled**
  - Run resolves as a retreat.
  - No chapter completion.
  - Player regroups and can reattempt.

---

## Guide NPC behavior in this chapter

Guide is a **risk mentor**: clear stakes, one action at a time, short repeatable reminders—**after** the player understands outfitting.

### Guidance beats

1. **Chapter intro beat (gearing)**
   - Point to **shared inventory** and **equip**: production and shop outputs become adventurer loadout.
   - Send the player to the **Forge** to craft **weapons and armor**; tie **smelter** output to **forge recipes** in one plain sentence (**smelt → forge → equip**).
   - Introduce the **blacksmith** as the worker tied to that fantasy (hire/assign when the loop exists; otherwise dialogue-only pointer).
   - Next step: select an adventurer and put on a sensible minimum loadout (wording can reflect “you choose,” not a hard gate).
2. **Stakes primer beat**
   - Introduce **expeditions** and explicit stakes (**death** and **equipped gear loss** on a bad run)—now that loadout is a known concept.
3. **Prep reminder beat** (Focus A reinforcement)
   - If no adventurer selected: prompt selection.
   - If no gear equipped: prompt a minimum loadout (nudge, not block).
   - If the player is staring at **greyed forge/blacksmith recipes:** name the **missing building or upgrade** and the **next place** to fix it (Forge lot, build menu)—still a nudge, not a launch block.
4. **Launch beat**
   - Confirm readiness and direct player to start the first route.
5. **Outcome beat**
   - `Victory`: celebrate and move player forward.
   - `Defeat`: confirm loss, point to rebuild loop (production/selling).
   - `Fled`: validate retreat and direct re-prep.

### Messaging rules

- Keep lines short (1-2 sentences).
- Always include the next actionable step.
- State penalties plainly; do not hide consequences in flavor text.

---

## Requirements checklist

### Focus A — Gearing up

- [ ] Player can unlock expeditions after chapter 1 completion (staging / prep access).
- [ ] Player can prepare at least one adventurer for a run (select + equip from shared inventory).
- [ ] Outfitting loop is supported by real items (craft/sell/commission paths as applicable—no empty-slot theater).
- [ ] **Forge** flow is taught: craft at least one **weapon** and one **chest** (or equivalent minimum kit) from **chapter 1 economy inputs** (ore, smelted plates, stone/wood line as designed—**not** dependent on expedition loot).
- [ ] **Forge UI** surfaces equippable recipes ahead of pure “materials only” churn for onboarding.
- [ ] **Blacksmith** beat ships: hire/unlock + first assignment **or** dialogue-only pointer consistent with what automation actually does.
- [ ] **Recipe building requirements** are authored for chapter-2-relevant crafts; forge UI and blacksmith assignment both respect the same rules.
- [ ] **First-run kit** remains achievable without expedition loot and **without** mandatory expensive building chains (optional stronger recipes may require more buildings).

### Focus B — First expedition

- [ ] First zone is repeatable until success.
- [ ] `Defeat` enforces permadeath + equipped gear loss.
- [ ] `Fled` resolves without chapter completion.
- [ ] First `Victory` marks chapter 2 complete.
- [ ] Guide has gearing intro, stakes primer, prep reminder, launch, and per-outcome follow-up beats.

---

## Tuning guardrails (initial)

- **First gear loop** should feel achievable on the chapter 1 economy (no new pity systems; no dependency on expedition loot to dress the first run).
- **Building gates** should gate **power and recipe variety**, not **expedition access**; if a recipe needs a new building, keep **gold + step count** low for the first such placement so chapter 2 stays “prep then run,” not a second smelter grind.
- First zone should be dangerous but fair for minimally prepared players.
- Expedition rewards should be meaningful, but not invalidate chapter 1 economy loops.
- Failure recovery should be economic (produce/sell/rebuild), not protected by pity systems.
