# Chapter 1 — Guild shop opening

Agreed design from planning sessions. Adjust as implementation proves otherwise.

---

## Pitch for this chapter

Establish the **guild shop management** fantasy: **two production tracks** on the lot, **selling** in the village, **optional** guild commission, and a **big gold goal** that ends the chapter when the player **places the smelter**.

**Outfitting and first expedition** are **not** in chapter 1—they start in chapter 2 (**gear up, then first run**; see [Chapter-02.md](Chapter-02.md)).

---

## Player beats (high level)

1. Basic **craft + sell** loop (village: market and/or villagers).
2. **Miner** and **lumberjack** on the lot — **two parallel tracks**, weighted by phase:
   - **First half:** emphasize **wood line** (setup for fuel).
   - **Second half:** emphasize **miner / ore** (most **gold** comes from this side once the chain is running).
3. **Charcoal** is **mandatory** on the critical path (player **must** craft it).
4. **First guild commission** is **optional** — if skipped, player **only misses gold** (no hard block, no exclusive lock for chapter completion).
5. Commission content should teach **both** lines: include **ore-side** and **wood/charcoal** (exact item IDs TBD in content).
6. After milestones, the **guide NPC** introduces **building X** (smelter) and its **high gold cost**; chapter completes when the player **can afford and places X**.
7. Closing dialogue: **vague tease** of chapter 2 (no specific spoiler beat required).

---

## Production graph

| Piece | Role |
|--------|------|
| **Miner** | Feeds **ore** (and downstream metal) into the shop. |
| **Lumberjack** | Feeds **wood** into a **machine** that outputs **charcoal**. |
| **Lumberjack machine** | Produces **charcoal**; present in ch1 but **not** the chapter “flag” building. |
| **Building X (miner machine)** | **Smelter / forge hearth** (semi-finished metal: ingots, plates, etc.). **Expensive**; **placing it ends chapter 1**. |

**Charcoal**

- **Consumed on every smelt** (ongoing sink; wood line stays relevant after X exists).
- **Smelter does not run** without charcoal (hard gate). Dialogue (and clear machine feedback) should state the requirement so placement without stock doesn’t read as a bug.

**Tuning (TBD)**

- Gold cost of **X** vs. income (remember: **no soft-cap** on other spends — workers, cheaper builds, adventurer hires can delay savings).
- **Charcoal per smelt** ratio — not locked yet.

---

## Sequencing (commissions vs. smelter)

To avoid requiring the smelter **before** the guide names **building X**:

- Early commission asks for **pre-smelter** outputs: **raw ore** and **charcoal** (and/or other wood-line products as needed), **not** ingots/plates.
- **Later** commissions (after smelter exists) can require smelted goods.

---

## Guide NPC (dialogue-only)

- **Not** a separate objective UI — the NPC **tells** the player what to do next.
- **Auto-greet** when the player is in range **after a milestone**, **every approach** until they **engage** (talk).
- **Dialogue advances** when the player **talks** again after the greet.
- **Same NPC** is intended to guide **future chapters** (avoid infinite dialogue bloat later — short lines, repeatable reminders).

**Risk:** parallel tracks + charcoal gate are easy to forget; use **repeatable** barks (“We need charcoal before the hearth will light,” etc.).

---

## Chapter completion

- **Condition:** Player has **earned enough gold to afford building X** and **places X** (placement is the celebratory beat; **M** = the meaningful gold requirement for that purchase, not a separate “lifetime earned” stat).
- **Follow-up beat:** Guide **teases chapter 2** in **vague** terms only.

---

## Open items (chapter 1)

- [ ] Exact **first commission** item list (ore + charcoal quantities).
- [ ] **Smelter** cost and income curve playtest.
- [ ] **Charcoal-per-smelt** ratio.
- [ ] Villager vs. market **pricing** differentiation for ore vs. charcoal (if not parity).
- [ ] Script: full dialogue beats + milestone flags for auto-greet.
