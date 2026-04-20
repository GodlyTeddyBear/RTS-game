# Foundation (global)

Cross-chapter vision, pillars, and implementation anchors. **Chapter-specific beats live in `Chapter-0x.md`.**

---

## Vision

**Guild shop management simulator:** players **run production** on a private lot, **sell** in the village (**general market** and **NPC villagers**), and work with the **guild** (commissions, later expeditions). Crafted goods feed the economy and equip **adventurers** who fight for **loot**. Progression is presented as **one primary track** (chapters, building unlocks, reputation, player level) even if multiple numbers exist under the hood.

---

## Design pillars

| Pillar | Player-facing idea |
|--------|---------------------|
| **Readable places** | Village = **money & guild**; remote lot = **making things**. Instant travel. |
| **One inventory, many jobs** | Same items → **sell**, **commission**, or **adventurer gear**. |
| **Guild as hub** | Commissions and adventurers share the guild fantasy. |
| **Stakes on expeditions** | Serious but fair: **dead adventurers are removed**; **their gear is lost**. No special protection for new accounts; **no recovery handouts** after a wipe. |

---

## World structure

| Place | Role |
|--------|------|
| **Village** | Selling (market + villagers), guild (commissions, adventurers, expedition staging). |
| **Remote production lot** | Workers, **buildings as factory machines**, crafting → shared inventory. |

**Travel:** Instant.

---

## Core loops

1. **Produce** — Workers + buildings; output to **shared inventory**.
2. **Monetize** — Sell for **gold** (market and villager rules as implemented).
3. **Commissions** — Deliver **item + quantity**; rewards **gold**, **tokens**, sometimes **items**; **tiers** filter pools. Can offer **exclusives** or **more gold** vs. selling; selling stays broadly viable.
4. **Expeditions** — From **chapter 2** onward: **outfit adventurers from shared inventory**, then **zones**, loot, **Victory / Defeat / Fled**; permadeath + gear loss on deaths.

**Player model:** *make → sell or turn in; chapter 2 onward: equip → fight → loot.*

---

## Player level (XP)

- Sources: **production** and **combat wins**.
- **Early game:** **sales** are the largest XP contributor — includes **market sell**, **villager sell**, and **commission delivery** (same bucket).

---

## Selling channels

- **General market:** bulk, relatively stable pricing (tone).
- **Villagers:** niche requests, **somewhat better** unit value when the ask matches (tone). **Per-item split for ore vs. charcoal (etc.)** still TBD.

---

## As-built alignment (code-backed)

- **Profile:** `Guild` (adventurers), `Commission` (board, active, tokens, tier, refresh), `Quest` (expedition, completed count), `Production` (workers, buildings), **shared inventory**, per-adventurer **equipment**.
- **Commissions:** Tier-filtered pools; deliver grants gold/tokens/items.
- **Expeditions:** Zones, loot tables, resolved outcomes; completed count persists.

---

## Progression spine (ongoing)

- Chapters map to **one journey** for the player.
- Commissions: mix **random board** with **directed** beats where needed; **token spend** should stay meaningful long-term.
- See chapter files for **what happens in each chapter**.

---

## Economy (design categories)

| Flow | Examples |
|------|----------|
| **Faucets** | Sells, commissions, expedition wins, starter gold |
| **Sinks** | Workers, buildings, hires, materials consumed in recipes (e.g. charcoal per smelt), future token sinks |
| **Stock** | Inventory + equipped gear on adventurers |

Tune in config; chapter docs call out chapter-specific sinks (e.g. smelter fuel).

---

## Session beats (Roblox-shaped)

| Length | Healthy outcomes |
|--------|------------------|
| **2–5 min** | Collect production, sell or one commission step, set next craft. |
| **15–30 min** | Push chapter goal, tune queues, prep for next chapter systems. |

---

## Conflicts between loops (resolve in chapter or Foundation when locked)

- Commissions vs. selling vs. gearing — document rules when you lock pool content.
- Wipe recovery is **economic only** (earn back); no pity systems by current intent.

---

## Roadmap (engineering / cross-chapter)

- Onboarding clarity; token sinks visible; telemetry (sessions, commission flow, expedition outcomes, sell vs. deliver).
- Performance, sync, tooling per project standards.
- Optional later: dynamic pricing, prestige, achievements — only if pillars hold.

---

## Balancing & metrics (living)

| Signal | Meaning |
|--------|---------|
| Commission abandonment | Requirements vs. capability, expiry, rewards |
| Board ignored | Payout vs. sell |
| Early wipe rate | Combat vs. crafting disconnect |
| Token pile-up | Missing spend |

---

## Legacy concept (not current product pitch)

Old doc: forge → brewery → enchant, click bonuses, formal supply/demand formula. Deprecated as the main description; ideas may be mined later.

---

## Notes

- If prices become dynamic, teach **why** before it feels punitive.
- **Production ↔ expeditions:** loot and crafts should reinforce each other (from chapter 2 on).
