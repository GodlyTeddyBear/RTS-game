# Entity Implementation Pipeline

This document defines the full backend pipeline for adding a new entity family or a new entity variant inside an existing owning context.

Canonical method and architecture references:
- [BACKEND.md](BACKEND.md)
- [DDD.md](DDD.md)
- [ECS_OVERVIEW.md](ECS_OVERVIEW.md)
- [SYSTEMS.md](SYSTEMS.md)
- [../../methods/backend/CONTEXT_BOUNDARIES.md](../../methods/backend/CONTEXT_BOUNDARIES.md)
- [../../methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md](../../methods/backend/INFRA_RUNTIME_PERSISTENCE_CONTRACTS.md)
- [../../methods/ECS/COMPONENT_RULES.md](../../methods/ECS/COMPONENT_RULES.md)
- [../../methods/ECS/ENTITY_FACTORY_RULES.md](../../methods/ECS/ENTITY_FACTORY_RULES.md)
- [../../methods/ECS/SYSTEM_RULES.md](../../methods/ECS/SYSTEM_RULES.md)
- [../../methods/ECS/ECS_PERSISTENCE_RULES.md](../../methods/ECS/ECS_PERSISTENCE_RULES.md)
- [../../../Templates/README.md](../../../Templates/README.md)
- [../../../Templates/ai-runtime-context.md](../../../Templates/ai-runtime-context.md)
- [../../../Templates/ai-runtime-creator.md](../../../Templates/ai-runtime-creator.md)

---

## Overview

- Use this pipeline when adding a new entity family such as `Structure`, `Enemy`, `Unit`, `Summon`, `Resource`, or a new variant inside one of those families.
- Start from the owning bounded context. The shared runtime never becomes the owner of context-specific configs, profiles, adapters, resolvers, or instance policy.
- Treat the pipeline as data first, ECS second, runtime bridge third, and projection or persistence last.
- If the new entity introduces a brand-new bounded context, read the backend-context template path from [../../../Templates/README.md](../../../Templates/README.md) before creating files.
- If the new entity only adds a new type inside an existing context, prefer extending the context's existing config, runtime profile registry, systems, and factories instead of creating a parallel context.

---

## Rules

### 1. Choose the owning context before writing files

- Put the new entity in the context that owns its business rules, lifecycle, and persistence shape.
- Create a new bounded context only when the entity needs separate application flows, separate persistence ownership, or separate ECS world ownership.
- Do not move context-specific policy into `Combat`, `Mining`, or another shared runtime owner just because the entity uses that runtime.

### 2. Start with canonical data and type shape

- Add or extend the shared config record in `ReplicatedStorage/Contexts/<Context>/Config/`.
- Add or extend the shared types in `ReplicatedStorage/Contexts/<Context>/Types/`.
- Put stable identity fields in config or types first, then make factories and adapters consume those fields.
- Define the canonical variant selector in data, usually a field such as `RuntimeProfileId`, `Class`, `Role`, or `BehaviorType`.
- Do not hardcode variant selection rules in adapters or sync services when config can own them.

### 3. Register the entity in the context's error and dependency surface

- Add any context-specific error constants to `Errors.lua` when the new entity adds new failure paths.
- Register new modules in `<Context>Context.lua` so `BaseContext` owns lifecycle and dependency resolution.
- Keep module placement aligned with the existing context layout:
  - `Infrastructure/ECS/` for world, components, entity factory, instance factory, and systems
  - `Infrastructure/Persistence/` for sync and persistence bridges
  - `Infrastructure/Services/` for runtime helpers, adapters, and non-persistence services
  - `Infrastructure/Runtime/` for profiles and resolver factories when the entity uses a shared runtime

### 4. Extend or create the ECS schema

- Add any required components or tags in the context's `*ComponentRegistry`.
- Keep components as pure data and tags as binary markers.
- Create only the components needed for authoritative runtime state, not convenience mirrors of data that already exists elsewhere.
- Do not let application or domain modules mutate JECS directly; all ECS writes must go through the `*EntityFactory`.

### 5. Implement the entity factory as the only ECS mutation surface

- Create or extend `<Context>EntityFactory` methods for:
  - entity creation
  - identity reads
  - runtime state reads and writes
  - model or instance refs
  - queries used by systems, sync, and adapters
  - deferred deletion and cleanup
- Keep the factory responsible for ECS entity lifecycle and typed access only.
- Do not let the factory own Workspace parenting, live model creation, behavior profile selection, or ProfileStore writes.

### 6. Add systems only for phase-owned runtime logic

- Add ECS systems when the entity needs recurring stateless phase behavior such as targeting, cooldown ticking, reveal stamping, or runtime state derivation.
- Declare reads and writes clearly through factory APIs.
- Split behavior across phases when ordering matters instead of relying on implicit sequencing inside one large system.
- Do not turn adapter services or sync services into hidden systems that own recurring ECS mutation.

### 7. Add instance lifecycle ownership when the entity has a live model

- Create or extend an `*InstanceFactory` when the entity owns Roblox instances or models.
- Keep instance ownership limited to:
  - asset lookup
  - clone or build
  - parenting
  - reveal metadata
  - baseline attributes
  - cleanup
- Store lookup refs such as `ModelRef` through the entity factory after bind.
- Do not let the instance factory become the source of truth for authoritative game state.

### 8. Add persistence and sync as bridge layers, not ownership layers

- Add or extend a `*GameObjectSyncService` when ECS state must project to a model or atom-backed runtime view.
- Add or extend a `*PersistenceService` when ECS state must serialize to `profile.Data`.
- Keep sync services projection-only and optional polling-only where the context explicitly owns polling.
- Keep persistence services limited to plain-data bridge logic.
- Do not let sync or persistence services create entities, destroy entities, or choose behavior definitions.

### 9. Add runtime profile ownership when the entity participates in a shared runtime

- Add `Infrastructure/Runtime/Profiles/<Context>RuntimeProfiles.lua` when the entity needs combat, mining, AI, or another runtime-driven behavior family.
- Put all variant-specific runtime policy there:
  - `BehaviorDefinition`
  - `TickInterval`
  - animation-state resolution
  - looping rules
  - variant fallback logic
- Resolve variants from canonical config or identity data.
- Add new variants by extending the profile registry, not by growing `if Variant == ...` branches across adapters and sync services.

### 10. Add adapters and resolvers as the bridge into shared runtimes

- Create one adapter service per runtime owner, such as `StructureCombatAdapterService` and `StructureMiningAdapterService`.
- Keep each adapter thin:
  - configure the runtime owner
  - register actor type once
  - register and unregister actors
  - build facts and services callbacks
  - resolve the runtime profile
- Extract callback-building and proxy wiring into `Runtime/Resolvers/*Factory.lua`.
- Do not let the shared runtime own context-specific payload details, facts rules, resolver tables, or profile registries.

### 11. Wire application flows to the full entity lifecycle

- Add or extend application commands and queries so entity creation, lookup, mutation, damage, cleanup, and save or load flows use the factory and service boundaries correctly.
- Ensure removal flows unregister runtime actors before deleting live entity state when the entity is runtime-owned.
- Ensure create flows register sync projection and runtime actors after the entity and model exist.
- Keep business validation in application or domain code, not inside low-level infrastructure helpers.

### 12. Treat multi-runtime entities as one context with multiple bridges

- When one entity family participates in multiple runtimes, keep one owning context and add one adapter per runtime owner.
- Share config, entity factory, instance ownership, and sync projection inside the owning context.
- Split only the runtime bridge pieces:
  - adapter service
  - runtime profile selection path when needed
  - resolver factories specific to that runtime
- Do not duplicate the entity family into multiple contexts just because it talks to multiple shared runtimes.

---

## Full Pipeline

### New entity family inside a new owning context

1. Choose the owning context and read the matching templates.
2. Create config, types, and errors.
3. Create the context service and register modules.
4. Create the ECS world service, component registry, entity factory, and required systems.
5. Create the instance factory when the entity owns live models.
6. Create sync and persistence bridges.
7. Create runtime profiles, adapters, and resolver factories when the entity participates in a shared runtime.
8. Add application commands and queries for create, mutate, query, cleanup, and persistence orchestration.
9. Connect profile load and save flows when the entity is persisted.
10. Verify create, tick, sync, unregister, delete, and save or load flows end to end.

### New variant inside an existing entity family

1. Extend shared config and types with the new variant record.
2. Extend the runtime profile registry with the new variant's behavior and animation mapping when runtime-driven.
3. Extend entity factory creation logic only if the variant needs new authoritative ECS fields.
4. Extend systems only if the variant introduces new recurring phase logic.
5. Extend instance factory setup only if the variant changes model creation or reveal policy.
6. Extend sync projection only when the projected attributes genuinely differ.
7. Avoid adding variant branches in multiple layers when one profile or config table can own the difference.

---

## Structure Example

The `Structure` pipeline is the canonical example of a multi-runtime entity family:

```text
ReplicatedStorage/Contexts/Structure/
  Config/StructureConfig.lua
  Types/StructureTypes.lua

ServerScriptService/Contexts/Structure/
  StructureContext.lua
  Application/
    Commands/RegisterStructureCommand.lua
    Commands/ApplyDamageStructureCommand.lua
    Commands/CleanupAllCommand.lua
    Queries/GetActiveStructuresQuery.lua
  Infrastructure/
    ECS/
      StructureComponentRegistry.lua
      StructureECSWorldService.lua
      StructureEntityFactory.lua
      StructureInstanceFactory.lua
    Persistence/
      StructureGameObjectSyncService.lua
    Runtime/
      Profiles/
        StructureRuntimeProfiles.lua
      Resolvers/
        StructureFactsResolverFactory.lua
        StructureTargetingResolverFactory.lua
        StructureProjectileResolverFactory.lua
        StructureMiningProxyResolverFactory.lua
        StructureFactoryProxyResolverFactory.lua
    Services/
      StructureCombatAdapterService.lua
      StructureMiningAdapterService.lua
      StructureTargetingSystem.lua
      StructureAttackSystem.lua
```

Structure-specific rules:

- `StructureConfig` owns the canonical `RuntimeProfileId` for each structure type.
- `StructureEntityFactory` owns authoritative structure ECS state and lookups.
- `StructureInstanceFactory` owns the live model lifecycle.
- `StructureGameObjectSyncService` projects runtime state to the model and resolves animation through `StructureRuntimeProfiles`.
- `StructureCombatAdapterService` bridges attack-capable structures into `CombatContext`.
- `StructureMiningAdapterService` bridges extractor structures into `MiningContext`.
- `StructureRuntimeProfiles` centralizes `Attack` versus `Extract` behavior selection and animation mapping.
- Resolver factories keep callback and proxy construction out of the adapters.

### Canonical create flow

```text
RegisterStructureCommand
  -> StructureEntityFactory creates entity
  -> StructureInstanceFactory creates or binds model
  -> StructureGameObjectSyncService registers projection
  -> StructureCombatAdapterService registers actor when RuntimeProfileId == "Attack"
  -> StructureMiningAdapterService registers actor when RuntimeProfileId == "Extract"
```

### Canonical removal flow

```text
ApplyDamageStructureCommand or CleanupAllCommand
  -> unregister combat actor when present
  -> unregister mining actor when present
  -> destroy or clean live model ownership
  -> delete entity through StructureEntityFactory
```

---

## Anti-Patterns

- Do not add a new entity by editing only the adapter service. The pipeline starts earlier at config, types, and ECS ownership.
- Do not store variant policy in both config and runtime profiles. Config selects the variant; profiles define what that variant means at runtime.
- Do not place projection logic, instance creation, and ECS mutation in one module.
- Do not let runtime-owner contexts such as `Combat` or `Mining` accumulate context-specific entity rules.
- Do not add repeated `if Type == ...` branches across sync services, adapters, and systems when one profile table can own the difference.
- Do not skip unregister flow when deleting runtime-owned entities.
- Do not add persistence writes directly in commands when a persistence bridge already owns the serialization boundary.

---

## Cross-References

- Use [../../../Templates/backend-context.md](../../../Templates/backend-context.md) when the entity requires a new bounded context.
- Use [../../../Templates/backend-service.md](../../../Templates/backend-service.md) when adding a new service module inside an existing context.
- Use [../../../Templates/backend-syncservice.md](../../../Templates/backend-syncservice.md) when adding a sync bridge.
- Use [../../../Templates/ai-runtime-context.md](../../../Templates/ai-runtime-context.md) when the context consumes a shared runtime.
- Use [../../../Templates/ai-runtime-creator.md](../../../Templates/ai-runtime-creator.md) when the task is creating a new runtime-owner context instead of a runtime consumer.
