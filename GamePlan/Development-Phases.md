# Development Phase Plan

This document defines production gates for building RTS from preproduction to a solo v1 ship, then co-op.
Phases are execution gates, not calendar promises.

Design lock source: [docs/GDD.md](../docs/GDD.md)
Planning contract source: [.codex/documents/methods/PLAN_DEVELOPMENT.md](../.codex/documents/methods/PLAN_DEVELOPMENT.md)

## Goal

Ship a solo-first Roblox wave-defense v1 where the player **commands**, **collects resources**, **places structures**, uses **abilities** to fight, and **defends a base** while **developing** between waves — a clear **prep -> combat -> payoff** loop, then transition into **endless mutator pressure**, a **trustworthy score breakdown**, and stability for live iteration.

## Success Criteria

- New players can complete a first run without blockers and can explain why they won or lost.
- Median run length for target players is in the 20-30 minute band before death in internal playtests.
- The score breakdown explains gains/losses for at least 90% of reviewed runs.
- Core server-authoritative systems (run state, combat outcomes, spending, unlock effects) are exploit-resistant at v1 scope.
- Solo v1 ships with defined content-complete criteria and a rollback-safe tuning process.

## In Scope / Out of Scope

### In Scope

- Solo-first run loop from lobby to results.
- Commander-based lane defense: **enemy design goal = destroy the base (command post)**; **player goals = survive and develop**; prep/combat cadence with rest to **build and develop** between waves.
- Scripted climax then endless waves with mutator escalation.
- Score pipeline with inspectable breakdown fields.
- Light meta progression that changes options, not raw stat creep.
- Production hardening for performance, telemetry, and release hygiene.

### Out of Scope

- Campaign narrative structure and cinematic mission flow.
- Multi-lane RTS macro management.
- PvP balance and competitive modes.
- Co-op implementation before a shippable solo v1 gate.

## Unknowns + Resolution Plan

**Design locks (see [GDD](../docs/GDD.md))** — the following are **no longer** open at roadmap level: **resource names and shape** (Energy + **Ferrium, Ceren, Voltrite**; **Scrap** with **Prep** conversion and tax; soft caps) — GDD **§7**; **climax** as **wave 10** **siege** set piece (**not** a bespoke **boss**), **wave 9** siege **preview** — GDD **§10.3**; **endless mutators** at **2** **active** with **rotation** (period **N** in tuning) — GDD **§10.4**.

| Unknown | Why It Matters | Owner | Resolution Gate | Fallback Default |
|---|---|---|---|---|
| Economy **numeric** balance (income, costs, Scrap spawns, cap numbers) | Drives feel, prep tension, and anti-snowball in play | Design + EconomyContext owner | **End of Phase 3** (tuning alongside core loop) | GDD **§7** placeholder caps and conversion; iterate from internal playtests |
| Mutator **rotation period (N)**, **pairing** bans, and extra deck entries beyond the **12** in GDD | Clarity and variety without stacked gotchas | Design + Runtime systems owner | **End of Phase 4** | GDD: suggest **3–5** waves per cycle; keep **2**-active cap; v1 “hard but fair” tone |
| Score exploit policy thresholds | Required for leaderboard trust | Design + Scoring owner | End of Phase 4 | Disable leaderboard publishing until exploit checks pass |
| Meta progression depth for v1 | Scope risk and balance risk | Product + Meta owner | End of Phase 5 | Horizontal unlocks only; no flat damage multipliers |
| Co-op resource/life model | Avoids rework in core loop later | Product + Systems owner | End of Phase 7 planning lock | Shared wave pressure, explicit revive rule, no silent carry-over assumptions |

## GDD Section

### Problem Statement

Current planning content is directionally strong but not consistently decision-complete. Teams can start building without explicit ownership, verification gates, or risk closure criteria.

### Target Player

Players who want short tactical sessions with fast decision-making, escalating pressure, and a readable post-run performance story.

### Core Loop Impact

This phase plan forces every major loop step (prep, combat, reward, endless, results) to have explicit gates so loop quality is validated before adding breadth.

### Goals

- Convert roadmap intent into measurable production gates.
- Preserve vertical-slice-first strategy before scaling content.
- Define owner-scoped deliverables for client, server, and shared layers.
- Attach explicit validation criteria to each phase exit.

### Non-goals

- Final balance numbers in this document.
- Detailed per-feature implementation tasks at code level.
- Art style guides or monetization planning.

### Constraints

- Keep authority boundaries consistent with server ownership of gameplay truth.
- Keep design readable under Roblox performance limits.
- Avoid broad refactors that do not directly serve the current phase gate.

### Success Metrics

- Phase exit checks are pass/fail and executable.
- Unknowns are either resolved at the declared gate or moved with explicit fallback assumptions.
- No phase advances with missing hard-gate deliverables.

### Acceptance Criteria

- Every phase includes deliverables, owner scope, and exit criteria.
- Validation and security checks exist for high-risk systems (networking, persistence, scoring).
- A rubric score and approval status is present and actionable.

## Implementation Section

### Architecture Boundaries

| Layer | Ownership | Responsibilities in This Plan |
|---|---|---|
| Server (authoritative) | `ServerScriptService/Contexts/*` | Run state machine, wave progression, combat outcomes, resource mutation, score event integrity, persistence writes |
| Client (presentation/orchestration) | `StarterPlayerScripts/Contexts/*` | Input, HUD, read models, local feedback, result visualization, onboarding cues |
| Shared contracts | `ReplicatedStorage/Contexts/*` and event contracts | Types, config, sync atoms, remote payload schemas |

### Data Contracts (phase-level)

| Contract Area | Required Shape Decision by Gate |
|---|---|
| Run state | Enumerated states (`Lobby`, `RunPrep`, `RunCombat`, `Results`) finalized by Phase 1 |
| Base (command post) | Authoritative **base** id/HP, binding to **base_anchor** (GDD §9), and **run loss** when base HP = 0 — finalized by Phase 1 |
| Wave script | Hand-authored composition schema finalized by Phase 2 |
| Resource state | **GDD-locked** names and rules (see **§7**). **Server** wallet schema, validation, and **numeric** **tuning** (income, costs, cap numbers) finalized by **Phase 3** |
| Score state | Pillar breakdown and audit fields finalized by Phase 4 |
| Meta state | Profile unlock/loadout schema versioned by Phase 5 |

### Network Contracts

- All write intents are client -> server requests with strict payload validation.
- All gameplay outcomes are server -> client replicated state or trusted events.
- Remote contracts are schema-validated at server ingress and reject out-of-range values.
- No client-only mutation source is allowed for combat, economy, unlocks, or score totals.

### Validation and Security Rules

- Server authority is mandatory for run progression, damage, spawning, spending, crafting, upgrades, and scoring.
- Input validation includes type, bounds, ownership checks, and current run-state eligibility.
- Persistence writes are context-owned and versioned to avoid schema drift.
- Score exploit monitoring is required before leaderboard publication.

### Sequencing

| Phase | Objective | Owner Scope | Hard Deliverables | Exit Gate |
|---|---|---|---|---|
| 0 Preproduction Lock | Freeze expensive reversals | Design + architecture owners | Economy and scoring specs in GDD, paper vertical slice, cut list, co-op assumptions appendix | Team can explain wave-1 teaching goal and replay motivation without ambiguity |
| 1 Run Shell | Playable empty run with authority boundaries | Runtime + UI shell owners | Run state machine, **commander + base (command post) lifecycle and loss** on commander or base zero HP, minimal HUD/results, dev controls, core logging hooks | New player can finish null run without errors |
| 2 Vertical Slice | Prove one fun loop in one lane | Combat + encounter + placement owners | 6 hand-authored waves, one structure, one summon/deployable, prep/combat transitions, reward stub | Playtesters can identify loss reasons without coaching |
| 3 Core Loop Completion | Fill pre-endless loop quality | Content + onboarding owners | Structure/enemy role expansion, reward pipeline, scripted climax, onboarding beats | Sessions stabilize near target length and losses are tactical, not confusion-driven |
| 4 Endless + Score | Credible endless and score integrity | Runtime + scoring owners | Endless driver, mutator system, score bus + results breakdown, personal best persistence | Score breakdown answers gain/loss logic for most runs and exploit loops have counters |
| 5 Meta Progression | Return motivation without invalidating difficulty | Meta + profile owners | Unlock/loadout system, profile migration/versioning, horizontal progression set | Session-2 retention bar met without flattening early-wave challenge |
| 6 Polish + Ship Prep | Production readiness | Performance + release owners | Perf budgets, telemetry, error reporting, UX readability pass, bug bash and rollback-ready release process | Soak testing has no critical crash class and v1 content-complete definition is met |
| 7 Co-op Product Phase | Multiplayer without core rewrite | Networking + session owners | Session model, scaling model, disconnect/rejoin policy, anti-grief basics, co-op UI clarity | Two-player runs are stable with explicit grief-handling policy |

### Risks and Mitigations

| Risk | Impact | Mitigation | Gate |
|---|---|---|---|
| Early scope spread before fun proof | Delays and brittle systems | Block breadth work until Phase 2 exit passes | 2 |
| Weak authority boundaries | Exploit risk and desync | Enforce server-owned outcomes and ingress validation rules | 1-7 |
| Endless mode lacks readability | Player confusion and churn | Limit concurrent mutator complexity and expose active rules clearly | 4 |
| Score system gamed by low-interaction loops | Leaderboard distrust | Add exploit detectors, cap abuse loops, and gate publishing | 4 |
| Meta progression power creep | Core loop invalidation | Bias horizontal unlocks and test veterans vs baseline runs | 5 |
| Performance collapse at high entity counts | Late ship blocker | Declare and enforce entity/pathing/VFX budgets before polish freeze | 6 |

### Test Scenarios

| Category | Scenario | Expected Result | Phase |
|---|---|---|---|
| Functional | Lobby -> run -> results full cycle | No blockers, clean teardown, repeatable restart | 1 |
| Functional | Prep placement + combat + reward transition | State transitions are consistent and UI reflects state | 2 |
| Edge | Commander dies during transition windows | Deterministic run end handling and valid results snapshot | 1-3 |
| Edge | **Base (command post) HP** reaches zero during wave or prep | Run ends; snapshot and results match GDD **Loss (base)** | 1-3 |
| Security | Malformed/forged placement request | Server rejects request and logs validation failure | 2-7 |
| Security | Client attempts score mutation | No score mutation without server event source | 4-7 |
| Performance | High-wave stress with configured entity cap | Frame stability remains within declared budget envelope | 4-6 |
| Persistence | Mid-run disconnect/rejoin policy path | Behavior matches explicit policy without corruption | 5-7 |

## Validation & Test Matrix

| Gate | Validation Checklist | Pass Condition |
|---|---|---|
| Phase 0 -> 1 | GDD v0: **§7** economy, **§8** scoring, **§10** roles/waves/mutators, **§3** onboarding; paper **vertical** slice; out-of-scope explicit | All lock artifacts reviewed and approved by owners |
| Phase 1 -> 2 | Null run test pass, authority map reviewed, logging hooks verified | 0 critical blocker defects |
| Phase 2 -> 3 | Vertical slice playtest, loss-readability check, first fun replay check | Majority of internal testers opt for immediate replay |
| Phase 3 -> 4 | Core loop pacing test, onboarding comprehension test | Target pacing band reached and confusion losses reduced |
| Phase 4 -> 5 | Endless stability test, score audit review, exploit pass | Score trust gate approved |
| Phase 5 -> 6 | Meta retention check, progression fairness check | Retention signal passes internal threshold |
| Phase 6 -> Ship | Soak, perf, telemetry, rollback drill | Release checklist complete with no critical crash class |
| Ship -> Phase 7 | Solo baseline stable post-release | Co-op work starts only after solo baseline health target is met |

## Rubric Score + Pass/Fail + Blocking Gaps

### Rubric Score

- Clarity: 2/2
- Completeness: 2/2
- Feasibility: 2/2
- Verifiability: 2/2
- Risk Coverage: 2/2

Total: 10/10

### Status

Approved

### Blocking Gaps

None for roadmap-level planning quality.

### Follow-up Required Before Phase 1 Starts

- **GDD §7** — resource **names**, **Scrap** conversion, and cap policy are **set**; implement **per** **Economy** / **Data contracts** (no further naming gate for Phase 1).
- Declare **owner** names for each phase in your internal **tracker**.
- Convert phase **hard deliverables** into **ticket** IDs with **due-gate** labels.
