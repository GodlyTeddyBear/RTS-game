# Chapter 4 — Guild commissions (rough draft)

**Status:** Rough draft — scope and beats to refine after Chapters 2–3 ship.

---

## Chapter intent

Chapter 4 makes **guild commissions** a **primary** loop, not an optional footnote. The player learns to **use the commission board** (accept, fulfill, deliver, abandon), **reason about inventory pressure** against the same **shared inventory** used for selling, crafting, equipping, and (after Chapter 3) potions, and **spend commission tokens** to **unlock higher tiers** with meaningfully different boards.

This chapter proves: **plan → produce → deliver** under guild pressure, and **tokens as progression** within the commission system.

---

## Locked decisions (draft)

- Chapter 4 is **centered on commissions**; general **market selling** and **villager** channels remain valid but are no longer the only obvious optimal path for every beat.
- **Chapter completion** is tied to **commission outcomes** (deliveries + tier progression), not to expedition firsts.
- **Token spend** must be **taught and used** for chapter progress (e.g. unlocking the next commission tier or a directed refresh beat — exact costs live in implementation config).
- **Directed commissions** are allowed where a purely random board would break pacing; random board + refresh still supports routine play.
- **Same inventory rule:** deliveries pull from the **shared inventory**; prepping a large contract can **compete** with gear, brew stock, and gold liquidity — by design, not as a hidden trap.
- **No new “commission-only” inventory** for MVP unless engineering already converges on that pattern.

---

## In-scope features (MVP — draft)

### Focus A — Board literacy (early)

- Teach **board vs active** commissions, **accept**, **deliver**, and **abandon** (consequences stated plainly in copy/UI).
- Teach **refresh** behavior at a high level (when it is available, what it changes).
- Early milestone: complete **a small number of deliveries** (exact N TBD) so the loop is muscle memory.

### Focus B — Tokens and tiers (mid)

- Introduce or reinforce **commission tokens** as a **persistent** reward from deliveries.
- Milestone: **unlock the next commission tier** by spending tokens (parity with existing `UnlockTier` style flow).
- At higher tier, player should **see** different board size and/or pool quality (data-driven; exact tables TBD).
- Optional: **one** commission entry that **only appears** at tier2+ so tier unlock feels load-bearing, not cosmetic.

### Focus C — Capstone contract (late)

- One **signature** commission (directed content) with **higher quantity** and/or **tighter planning** than tutorial-tier jobs — still achievable with Chapters 1–3 production breadth (exact item IDs TBD).
- Chapter completes when the player **delivers the capstone** and meets any secondary requirement locked during implementation (e.g. “must be at tier ≥ 2” — TBD).

---

## Out of scope (Chapter 4 MVP — draft)

- Replacing or hard-gating **all** gold income behind commissions.
- Full **reputation/faction** web tied to every commission (can be teased; not required for this chapter’s MVP).
- **Dynamic pricing** overhaul for market vs commission payout math.
- New expedition zones as the **chapter gate** (expeditions may supply **optional** inputs for contracts if already implemented).
- **Token sinks** beyond tier unlock and documented refresh rules unless already in data — avoid inventing many new sinks in this rough draft.

---

## Systems alignment (as-built — reference)

Profile already includes **Commission** state: board, active, tokens, current tier, last refresh (see persistence template). Chapter 4 is primarily **content, gating, and teaching** on top of that model.

---

## Guide NPC behavior (draft)

Guide acts as a **guild clerk mentor**: short lines, always one next step.

### Guidance beats (draft)

1. **Board intro** — what the board is; accept vs active; deliver when ready.
2. **Inventory pressure** — same stock as sell/equip/brew; prioritize for the job you accepted.
3. **Abandon / refresh** — when walking away is correct; avoid shame-y tone; state consequences.
4. **Tokens and tiers** — save tokens, spend on unlock; what changes after unlock.
5. **Capstone** — read the contract, prep, then accept if ready.

### Messaging rules

- 1–2 sentences per beat; include the **next actionable step**.
- Do not hide **abandon penalties** or **delivery requirements** in flavor-only text.

---

## Requirements checklist (draft)

### Focus A — Literacy

- [ ] Player can accept, deliver, and abandon commissions with clear feedback.
- [ ] Player completes the early delivery milestone (N TBD).
- [ ] Guide covers board basics and inventory competition with other loops.

### Focus B — Tokens and tiers

- [ ] Player earns tokens from deliveries at least once (if not already guaranteed earlier).
- [ ] Player unlocks the next commission tier using tokens.
- [ ] Post-unlock board behavior matches tier config (board size / pool — verify in implementation).

### Focus C — Capstone

- [ ] Signature commission is authored and deliverable with intended chapter economy.
- [ ] Chapter completes on capstone delivery (+ any locked secondary rule).
- [ ] Failure paths remain economic (produce / sell / retry), not pity systems.

---

## Tuning guardrails (draft)

- **Payout vs sell:** capstone and tier-2 jobs should **reward** planning; avoid tuning where selling always dominates with zero friction unless that is an explicit economy decision.
- **Softhands:** do not require commissions that depend on **unimplemented** recipe lines; validate against Chapters 1–3 outputs.
- **Session length:** healthy 15–30 min push should be able to hit tier unlock + capstone prep; adjust quantities if sessions feel like pure grind.
- **Token curve:** tier unlock cost should feel **earned** by mid-chapter play, not a week-long hoard unless that is intentional for your live ops.

---

## Open items

- [ ] Exact **chapter entry** condition (post–Ch 3 flag vs parallel — TBD).
- [ ] **Tier** number that is the chapter target (e.g. unlock tier 2 — TBD).
- [ ] **Capstone** item list, quantities, gold/token rewards, and any time limit.
- [ ] Whether **refresh** is part of a mandatory beat or only optional efficiency.
- [ ] Copy pass for **abandon** and **expiry** (if commissions expire — match implementation).
