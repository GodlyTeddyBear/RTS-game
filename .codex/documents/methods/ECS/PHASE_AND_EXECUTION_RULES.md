# Phase And Execution Rules

Method contract for phase ownership and execution order in the shared `EntityContext` runtime.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [REQUEST_AND_OUTCOME_PIPELINE_RULES.md](REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Core Rules

- Phase order is declared once in shared Entity phase config and is the single source of truth.
- Every system belongs to exactly one phase.
- If ordering matters, use separate phases. Never rely on registration order inside one phase.
- Deferred destruction flushes only after runtime phases complete.
- Cleanup request resolution must happen before entity unbind or deletion when destruction preparation runs synchronously.
- Derived projection should run only after authoritative writes for that tick are complete.

---

## Shared Phase Model

The current shared runtime uses grouped phases such as:

```text
MovementGrid
-> MovementCalculate
-> MovementApply
-> PreSimulation
-> Simulation
-> PostSimulation
-> Sense
-> Decide
-> Commit
-> ActionStart
-> ActionAdvance
-> MechanicSpawn
-> MechanicImpact
-> DamageResolve
-> RequestResolve
-> Execute
-> CleanupResolve
-> Cleanup
```

Rules:

- `ActionStart` creates actor state from intent.
- `ActionAdvance` advances actor state.
- `MechanicSpawn`, `MechanicImpact`, `DamageResolve`, and `RequestResolve` progressively resolve work.
- `CleanupResolve` handles synchronous cleanup requests such as destruction preparation.
- `Cleanup` removes processed transient requests or expired transient state.

---

## Scheduling Rules

- The movement scheduler may run a subset of phases separately from the main combat scheduler when that split is explicit in the runtime.
- A phase subset must still preserve its declared order.
- A system must not assume another phase subset already ran unless the scheduler guarantees it.

---

## Examples

```lua
-- Correct: cleanup resolution has its own phase because it must finish
-- before entity unbind/delete continues.
entitySystemRegistry:RunPhases({ "CleanupResolve" })
```

```lua
-- Wrong: two same-phase systems depend on registration order
RegisterSystem("Execute", FirstPart)
RegisterSystem("Execute", SecondPart) -- assumes FirstPart already wrote data
```

---

## Prohibitions

- Do not rely on implicit order within a phase.
- Do not mix action start and request resolution into one phase when the sequencing matters.
- Do not delete entities before required cleanup resolution has completed.
- Do not write derived projection before authoritative state is stable for the tick.

---

## Failure Signals

- A system depends on another same-phase system running first.
- Cleanup side effects occur after the entity has already been unbound or deleted.
- A service performs hidden intra-phase sequencing outside the registered phase model.

---

## Checklist

- [ ] Phase order is declared in one shared source.
- [ ] Every system belongs to one phase only.
- [ ] Ordering-sensitive work is split across phases.
- [ ] Cleanup resolution completes before destructive teardown continues.
- [ ] Derived projection runs after authoritative writes.
