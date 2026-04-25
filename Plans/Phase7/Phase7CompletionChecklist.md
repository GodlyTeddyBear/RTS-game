# Phase 7 Completion Checklist

Aligned with [Phase7Plan.md](Phase7Plan.md), [docs/GDD.md](../../docs/GDD.md) §12, and [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) (Phase 7: Co-op Product Phase).

Use this checklist to decide whether Phase 7 is complete. **Do not start** until the **solo baseline** gate in `Development-Phases` (*Ship → Phase 7*) is satisfied.

## Preconditions

- [ ] **Solo v1** is live (or internal equivalent) and **solo baseline health** target is met — per [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) *Ship → Phase 7*
- [ ] **Co-op resource/life** model is **locked** in planning (unknown table: by Phase 7 planning lock; fallback documented if needed)

## Session and scaling

- [ ] **Session model** implemented: join, run start, ownership, leave/teardown without corrupting server state
- [ ] **Scaling model** implemented and **tunable** (threat vs player count — GDD §12)
- [ ] **Resource model** for co-op is **explicit** (shared vs split for GDD **§7** types — GDD **§12**); no silent carry-over bugs

## Life, loss, disconnect

- [ ] **Revive / bleed / run end** rules when one player or **base** state changes are **defined, implemented, and readable** in UI
- [ ] **Disconnect / rejoin** policy works and matches tests; **Persistence** edge cases reviewed (see `Development-Phases` test 5–7)

## Social and UI

- [ ] **Anti-grief basics** in place; **grief-handling policy** written and linked for support/ops
- [ ] **Co-op UI** passes clarity bar: roles, critical shared state, prep/combat distinction as needed

## Stability

- [ ] **Two-player** runs are **stable** under normal use (no systematic desync class in smoke + longer session pass)
- [ ] No **critical** crash class specific to multi-session / co-op paths

## Phase 7 exit check

- [ ] [GamePlan/Development-Phases.md](../../GamePlan/Development-Phases.md) Phase 7 hard deliverables and exit gate are satisfied
- [ ] Stakeholders sign off on **co-op product** scope and policy (not “co-op prototype”)
