# ECS Overview

This document is the high-level reference for how ECS is structured in this codebase, what each ECS-related class owns, and where sync and persistence responsibilities live.

Use this alongside:
- [SYSTEMS.md](SYSTEMS.md) for JECS and ProfileStore runtime context
- [STATE_SYNC.md](STATE_SYNC.md) for sync placement and cloning rules
- [../methods/ECS/WORLD_ISOLATION_RULES.md](../methods/ECS/WORLD_ISOLATION_RULES.md) for world ownership
- [../methods/ECS/ENTITY_FACTORY_RULES.md](../methods/ECS/ENTITY_FACTORY_RULES.md) for factory boundaries
- [../methods/ECS/RUNTIME_OBJECT_BOUNDARIES.md](../methods/ECS/RUNTIME_OBJECT_BOUNDARIES.md) for entity, instance, and sync ownership split
- [../methods/ECS/ECS_PERSISTENCE_RULES.md](../methods/ECS/ECS_PERSISTENCE_RULES.md) for ECS-to-ProfileStore persistence

---

## ECS Structure

ECS in this repo is split into a small set of owned roles:

| Role | Primary Responsibility | Does Not Own |
|------|------------------------|--------------|
| `*ECSWorldService` | Creates and owns the JECS world, initializes the registry, declares phase order, and ticks systems | Entity mutation APIs, Workspace instance lifecycle, persistence logic |
| `*ComponentRegistry` | Defines component and tag IDs, authority labels, debug names, and a frozen registry surface | Runtime mutation, world ticking, instance lifecycle |
| `*EntityFactory` | Owns JECS entity creation, typed reads/writes, queries, and deferred destruction | Workspace instance creation, reveal stamping, ProfileStore access |
| `*System` | Runs stateless phase logic over factory APIs, with explicit read/write declarations | Persistent state, long-lived mutable system state, direct world access |
| `*InstanceFactory` | Owns live Workspace instance creation, binding, template lookup, and cleanup for ECS-backed runtime objects | JECS world mutation, business logic, sync projection |
| `*SyncService` / `GameObjectSyncService` | Projects ECS state onto live instances or atom-backed runtime state; may also poll live instance state back into ECS when explicitly registered to do so | Instance creation/destruction, JECS ownership, cross-context business logic |
| `*PersistenceService` | Bridges ECS data to ProfileStore and back using plain data tables | Runtime instance lifecycle, direct JECS world ownership |

---

## Folder Boundaries

The intended placement is:

```text
Contexts/
`-- [ContextName]/
    |-- Application/
    |-- [ContextName]Domain/
    `-- Infrastructure/
        |-- ECS/
        |-- Persistence/
        `-- Services/
```

Important placement rule:

- `Infrastructure/ECS/` holds the world service, component registry, entity factory, and ECS systems.
- `Infrastructure/Persistence/` holds runtime sync services and ProfileStore persistence services.
- If a service mutates replicated runtime atoms or syncs ECS state into instances, it belongs in `Infrastructure/Persistence/`, not `Infrastructure/Services/`.

This repo uses `Persistence/` as the home for both persistence bridges and object-sync services because both are part of the infrastructure state bridge layer.

---

## How The Pieces Work Together

### 1. World service sets up the ECS runtime

The `*ECSWorldService` creates the JECS world, registers components, constructs the entity factory, constructs systems, and owns phase ticking.

It is the orchestration point for ECS runtime lifetime.

### 2. Component registry defines the data surface

The `*ComponentRegistry` declares component and tag IDs and freezes them after initialization.

It does not run logic. It only defines the ECS schema that factories and systems use.

### 3. Entity factory is the only mutation surface for JECS state

The `*EntityFactory` is the only place that should create, mutate, query, or defer-destroy entities.

Systems and application services call factory methods instead of touching the world directly.

### 4. Systems read and write through the factory

Systems are stateless. They read and write components through factory methods, and each system belongs to exactly one phase.

If ordering matters, split work across phases instead of relying on implicit system order.

### 5. Instance factory owns live model lifecycle

When an ECS entity has a corresponding Roblox instance, the `*InstanceFactory` owns that instance's creation, binding, reveal metadata, and cleanup.

The entity factory may store lookup references such as `ModelRef`, but that does not transfer runtime ownership away from the instance factory.

### 6. Sync service projects state

The sync service takes authoritative ECS state and pushes it onto the live instance or runtime atom it owns.

It may also poll live instance state back into ECS when the context explicitly registers that behavior.

It does not own creation, destruction, or JECS mutation.

### 7. Persistence service bridges ECS to ProfileStore

The `*PersistenceService` serializes only the persisted parts of ECS state into plain tables and writes them to `profile.Data`.

Hydration of entities from loaded data belongs to the factory and the application/context lifecycle that invokes it, not to the persistence service itself.

---

## Canonical Runtime Flow

```text
Application command
    -> EntityFactory creates or mutates entity
    -> InstanceFactory creates and binds model
    -> EntityFactory stores ModelRef or fallback lookup state
    -> SyncService projects mutable ECS state onto the model
```

For persistence-backed flows:

```text
ProfileLoaded
    -> PersistenceService reads plain data
    -> Factory hydrates entity state
    -> InstanceFactory binds live model if needed
    -> SyncService applies runtime projection
```

```text
ProfileSaving
    -> Context or command orchestrates save
    -> PersistenceService serializes ECS state
    -> Data is written to profile.Data
```

---

## Boundary Rules

- Only infrastructure code touches JECS directly.
- Domain and Application code call factory and service APIs only.
- `ModelRef` is a lookup convenience, not a runtime ownership transfer.
- Reveal or identity stamping belongs to the instance factory layer.
- Runtime projection belongs to the sync service layer.
- ProfileStore serialization belongs to the persistence service layer.
- Do not mix live instance ownership, ECS mutation, and persistence serialization in one class.

---

## Suggested Base Responsibilities

If you are implementing or reviewing a context, use this as the checklist for class responsibilities:

- `*ECSWorldService`: owns world lifetime, component registration, system construction, and tick order.
- `*ComponentRegistry`: owns component IDs, tag IDs, and frozen schema definitions.
- `*EntityFactory`: owns entity lifecycle and typed ECS access.
- `*System`: owns one narrow phase behavior and nothing else.
- `*InstanceFactory`: owns runtime object lifecycle in Workspace.
- `*SyncService`: owns ECS-to-instance or atom projection and optional polling.
- `*PersistenceService`: owns serialization to and from `profile.Data`.

---

## Prohibitions

- Do not let a system query the JECS world directly when a factory method exists.
- Do not let a sync service create or destroy instances.
- Do not let an instance factory become the source of truth for ECS state.
- Do not place runtime object sync in `Infrastructure/Services/` when it belongs in `Infrastructure/Persistence/`.
- Do not let a persistence service own live instance lifecycle or ECS world construction.

---

## Failure Signals

- A context cannot explain which class owns world lifetime, entity mutation, instance lifecycle, sync, and persistence.
- A sync service is placed in `Infrastructure/Services/` instead of `Infrastructure/Persistence/`.
- A class is responsible for both JECS mutation and Workspace instance lifecycle.
- A persistence service is creating or destroying ECS entities instead of only bridging data.

---

## Checklist

- [ ] World lifetime is owned by a dedicated `*ECSWorldService`.
- [ ] Component and tag IDs are frozen in a `*ComponentRegistry`.
- [ ] Entity creation and mutation happen only through `*EntityFactory`.
- [ ] Systems are stateless and phase-scoped.
- [ ] Runtime instance lifecycle is owned by `*InstanceFactory`.
- [ ] Object sync services live in `Infrastructure/Persistence/`.
- [ ] Persistence services serialize ECS state to and from `profile.Data`.
- [ ] No class mixes ECS mutation, instance lifecycle, and persistence serialization.
