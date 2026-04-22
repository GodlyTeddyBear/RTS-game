# Events Contracts

Defines strict authoring rules for GameEvents modules under `ReplicatedStorage/Events/GameEvents/`.

Canonical architecture references:
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Event Module Contract

Every event module must expose exactly two frozen tables:

- `events` — string constants, keyed by PascalCase name, valued as `"Context.EventName"`.
- `schemas` — keyed by the event string constant, valued as an ordered array of argument type strings.

Both tables must be frozen with `table.freeze`.


---
## Naming Rules

- Event keys are PascalCase (e.g. `WaveStarted`, `EnemyDied`).
- Event string values follow `"Context.EventName"` dot notation.
- The context prefix must match the owning module name exactly (e.g. `"Wave."`, `"Run."`, `"Commander."`).


---
## Schema Rules

- Each event in `events` has exactly one corresponding entry in `schemas`.
- Schema arrays list argument type strings in argument-emission order.
- An event with no arguments uses an empty array `{}`.
- Type strings are lowercase Luau primitives (`"string"`, `"number"`, `"boolean"`) or Roblox class names (`"Instance"`, `"CFrame"`, `"Vector3"`).


---
## Prohibitions

- Do not add methods, logic, or mutable state to event modules — they are pure data registries.
- Do not define an event key that has no matching entry in `schemas`.
- Do not use raw string literals for event names in callers — always reference via the `events` table constant.
- Do not place event modules outside `ReplicatedStorage/Events/GameEvents/`.
- Do not share a single module across unrelated contexts — one module per logical context group.


---
## Failure Signals

- A key in `events` has no matching entry in `schemas`.
- An event string value does not start with the module's declared context prefix.
- `events` or `schemas` is not frozen on return.
- A caller passes a raw string literal instead of an `events.*` constant to the event bus.
- Module exports functions, metatables, or non-table values alongside `events`/`schemas`.


---
## Checklist

- [ ] `events` table is frozen with `table.freeze`.
- [ ] `schemas` table is frozen with `table.freeze`.
- [ ] Every key in `events` has a matching entry in `schemas`.
- [ ] All event string values follow `"Context.EventName"` format with correct prefix.
- [ ] Schema arrays use valid Luau/Roblox type strings only.
- [ ] Module exports no methods, logic, or mutable state.
- [ ] Callers reference event names via `events.*` constants, never raw strings.

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

