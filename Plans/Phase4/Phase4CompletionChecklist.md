# Phase 4 Completion Checklist

Aligned with [Phase4Plan.md](Phase4Plan.md), [docs/GDD.md](../../docs/GDD.md) §8 and §10, and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 4: Endless + Score).

Use this checklist to decide whether Phase 4 is complete.

## Endless

- [ ] **Endless driver** runs after the scripted climax (or defined hand-off) without corrupting run state
- [ ] **Endless stability:** long sessions or high wave counts do not crash, desync, or soft-lock (see `Development-Phases` performance test 4–6)
- [ ] Losing in endless still reports **base** and/or **commander** loss clearly (GDD §5)

## Mutators

- [ ] **Mutator system** implements the GDD **§10.4** **deck** (v0 table); mutators are **rule-changing**, not only stat bumps
- [ ] **At most 2** mutators **active** at a time; **rotation** of slots every **N** waves (**N** set for v1, within GDD suggest **3–5** for first read tests)
- [ ] **Active** mutator **names** + **one-sentence** rules are always visible in endless UI — *readability* bar
- [ ] **Pairing** / extra-deck items documented if you exceed or curate the 12 (align with GDD “open (tuning)” in **§10.4**)

## Score and results

- [ ] **Score bus** (server) feeds **Efficiency, Aggression, Control**; **v0** design bias: **Aggression** largest marginal weight; pillars stay non-zero (GDD **§8**)
- [ ] **Results** expose **per-pillar** subtotals and **top drivers** per GDD **§8** “post-run breakdown” **v0**; field names can match data contract
- [ ] **Results screen** (or post-run) meets explainability (org **~90%** bar per `Development-Phases` where applicable)
- [ ] **Telemetry** (design from GDD **§8**) has an engineering mapping for **score audits** and **anomaly** flags as needed
- [ ] **No client score mutation** — verified against test scenario *Client attempts score mutation* (4–7)

## Persistence

- [ ] **Personal best** (and any related aggregates) **persist** with schema/versioning appropriate to your profile story
- [ ] Re-open / replay does not corrupt PB or run history

## Exploits and trust

- [ ] **Exploit pass** completed: low-interaction / monotonic strats do not trivially top score (GDD §8 anti-exploit; `Development-Phases` risk *Score system gamed…*)
- [ ] **Leaderboard** (if any): either passes exploit policy or **publishing disabled** per fallback until trust gate clears

## Phase 4 exit check

- [ ] [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) Phase 4 hard deliverables and exit gate are satisfied
- [ ] **Score trust gate approved** for Phase 4 → 5 (endless + score audit + exploit pass)
- [ ] The build is ready for **Phase 5** — [Phase5Plan.md](../Phase5/Phase5Plan.md) (meta progression, loadouts, profile expansion; see Development-Phases Phase 5 row)
