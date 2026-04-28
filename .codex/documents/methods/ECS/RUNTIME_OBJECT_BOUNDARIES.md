# ECS Runtime Object Boundaries

Defines strict ownership contracts for ECS runtime object architecture across entity factories, instance factories, and game-object sync services.

Canonical architecture references:
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/SYSTEMS.md](../../architecture/backend/SYSTEMS.md)
- [ENTITY_FACTORY_RULES.md](ENTITY_FACTORY_RULES.md)
- [INSTANCE_REVEAL_RULES.md](INSTANCE_REVEAL_RULES.md)

---

## Core Rules

- Follow the required contracts in the sections below.
- Treat Prohibitions, Failure Signals, and Checklist as pass/fail requirements.

---

## Ownership Split

### Entity Factory

- Owns JECS entity creation, mutation, typed reads/writes, queries, and deferred destruction.
- May store `ModelRef` and `Transform` style components when the ECS context needs runtime lookups or spatial fallback state.
- Does not own Workspace instance lifecycle, asset lookup, reveal stamping, or instance cleanup.

### Instance Factory

- Owns live Workspace instance lifecycle for ECS-backed runtime objects.
- Owns asset/template resolution, Workspace folder ownership, entity-instance binding, reveal metadata, and instance cleanup.
- Does not own JECS world mutation, component queries as a source of truth, or deferred entity deletion.

### GameObjectSyncService

- Owns mutable ECS-to-instance projection only.
- Reads authoritative ECS state and pushes runtime attributes, animation flags, transforms, or other mutable projection onto the resolved instance.
- Does not create instances, destroy instances, own reveal bindings, or mutate JECS state as part of projection.

---

## Dependency Contract

- Application commands orchestrate the runtime flow by calling the owned APIs of the entity factory, instance factory, and sync service in that order.
- Entity factories may expose model lookup helpers through `ModelRef`, but those helpers do not transfer model ownership away from the instance factory.
- Sync services may resolve models from:
  - an explicit model argument
  - the context instance factory
  - the entity factory's stored `ModelRef`
- Placement, request, or other upstream contexts may provide validated records, coordinates, occupancy decisions, or request payloads to the owning ECS context.
- Placement, request, or other upstream contexts must not own ECS-backed runtime model lifecycle when those models belong to another ECS context.

---

## Canonical Runtime Flow

```text
Application command
    -> EntityFactory creates entity
    -> InstanceFactory creates and binds model
    -> EntityFactory stores ModelRef / Transform fallback
    -> GameObjectSyncService projects mutable ECS state onto the model
```

```lua
local entity = self._entityFactory:CreateEnemy(enemyId, role, spawnCFrame, waveNumber)
local model = self._instanceFactory:CreateEnemyInstance(entity, role, enemyId, waveNumber)

self._entityFactory:SetModelRef(entity, model)
self._syncService:RegisterEntity(entity, model)
```

- The entity exists before the model is bound.
- The instance factory owns the model binding and cleanup path.
- The sync service owns mutable projection after the model exists.

---

## Boundary Clarifications

### `ModelRef` Storage

- `ModelRef` is an ECS lookup convenience, not a transfer of runtime ownership.
- Storing a model reference on the entity lets systems and sync services resolve the current model without querying Workspace directly.
- The owner of `DestroyInstance(...)`, reveal clear/apply, and folder parenting remains the instance factory.

### Reveal Ownership

- Identity/discovery reveal belongs to the instance factory layer.
- Sync services may set mutable attributes that reflect ECS state, but they must not split reveal ownership by also managing identity tags or canonical discovery attributes.

### Placement And Request Contexts

- A placement context may validate requests, spend resources, update occupancy, and publish a placed-record event.
- The ECS context that owns the structure, enemy, or other runtime entity must own the live ECS-backed model lifecycle for that runtime object family.
- If another context owns spawning or destroying those models, the runtime ownership split is incorrect even if synchronization still works.

---

## Non-Conforming Anti-Pattern

```text
PlacementContext spawns and destroys structure models
    -> StructureContext receives a placement record later
    -> StructureEntityFactory backfills ECS state
    -> StructureGameObjectSyncService only updates attributes on a model it does not own
```

Why this is non-conforming:
- `PlacementContext` becomes the runtime model owner for Structure ECS objects.
- `StructureContext` cannot own the full entity -> instance -> sync lifecycle of its own ECS family.
- Model lifecycle and ECS lifecycle become split across two bounded contexts.

Target correction:
- `PlacementContext` keeps placement request handling, occupancy, and placement records.
- `StructureContext` owns structure entity creation, structure instance creation/cleanup, and structure sync.
- A dedicated `StructureInstanceFactory` becomes the runtime model owner for structure ECS objects.

---

## Prohibitions

- Do not create or destroy ECS-backed runtime models in a non-owning context.
- Do not let an instance factory mutate JECS world state or become a query surface for business logic.
- Do not let a sync service create instances, destroy instances, own reveal binding lifecycle, or call raw JECS mutation APIs.
- Do not treat `ModelRef` storage in an entity factory as permission to move instance ownership into the entity factory.
- Do not split identity/discovery reveal responsibilities across both the instance factory and sync service.
- Do not leave runtime ownership ambiguous between placement/request services and the owning ECS context.

---

## Failure Signals

- A placement or request context spawns or destroys models for another context's ECS family.
- An entity factory is responsible for template lookup, Workspace folder ownership, or instance destruction.
- A sync service applies canonical reveal identity/tags or directly owns model creation/cleanup.
- An instance factory reads or mutates JECS world state as part of regular runtime ownership.
- The owning ECS context cannot fully reconstruct the runtime object lifecycle without another bounded context's runtime service.

---

## Checklist

- [ ] Entity factory owns JECS creation, mutation, queries, and deferred deletion only.
- [ ] Instance factory owns Workspace instance lifecycle, binding, reveal, and cleanup.
- [ ] Sync service owns mutable ECS-to-instance projection only.
- [ ] `ModelRef` usage is treated as lookup state, not runtime ownership.
- [ ] Identity/discovery reveal ownership is centralized in the instance factory.
- [ ] Placement/request contexts provide upstream records or validation only, not ECS-backed runtime model lifecycle.
- [ ] The owning ECS context can create, bind, sync, and destroy its runtime object family without delegating model ownership to another context.
