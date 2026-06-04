# Component Rules

Method contract for ECS component design in the shared `EntityContext` runtime.

Canonical architecture references:
- [../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md](../../architecture/backend/SHARED_ENTITY_ECS_ARCHITECTURE.md)
- [REQUEST_AND_OUTCOME_PIPELINE_RULES.md](REQUEST_AND_OUTCOME_PIPELINE_RULES.md)

---

## Core Rules

- Components are pure data. No methods, behavior, or hidden logic.
- One responsibility per component.
- Components refer to other entities only by entity id or stable scalar ids.
- Actor state and transient requests must be modeled separately.
- Tags are first-class zero-field markers. Prefer them over boolean fields when the state is binary.

---

## Authority Labels

### `[AUTHORITATIVE]`

- Source of truth written by exactly one system.

### `[DERIVED]`

- Read model or projection derived from authoritative state.
- Written only by its designated projection or sync system.

---

## State Shape Rules

### Actor State Components

- Belong on the actor entity.
- Represent what the entity is doing or what state it is currently in.

Examples:

- `Combat.AttackState`
- `Movement.MoveIntent`
- `AI.ActionState`

### Request Components

- Belong on transient request entities.
- Represent work that needs to be resolved.

Examples:

- `Combat.HealthChangeRequest`
- `Entity.CleanupOutcomeRequest`
- `Combat.HealthDepletedRequest`

---

## Registry Rules

- Schema and registry data must be frozen after initialization.
- ECS debug names must be explicit and prefixed by feature or context name.
- Raw component ids must not leak outside the schema or factory internals.

---

## Examples

```lua
-- Correct: persistent actor state
Combat.AttackState = {
    AbilityId = "StructureBullet",
    Phase = "Startup",
    StartedAt = now,
}
```

```lua
-- Correct: transient request entity payload
Combat.HealthChangeRequest = {
    SourceEntity = sourceEntity,
    TargetEntity = targetEntity,
    Amount = 20,
    ChangeType = "Damage",
}
```

```lua
-- Wrong: mixed persistent and transient concerns
Combat.AttackAndDamage = {
    Phase = "Active",
    DamageToApplyNow = 20,
}
```

---

## Prohibitions

- Do not mix actor state and transient request work into the same component.
- Do not store callbacks, Instances, or service handles in authoritative gameplay components unless the component is explicitly runtime-internal.
- Do not let multiple systems write the same authoritative component.

---

## Failure Signals

- A component mixes long-lived actor state with one-frame work.
- A request payload is stored on the actor when it should be a transient request entity.
- A component exists only because a service needs somewhere to hide logic state.

---

## Checklist

- [ ] Components are pure data.
- [ ] Actor state and transient requests are separated.
- [ ] Tags are used for binary state.
- [ ] Authority ownership is clear.
- [ ] Registry ids stay internal.
