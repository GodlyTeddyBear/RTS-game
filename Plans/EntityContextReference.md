# EntityContext Reference

Reference for the "single ECS kernel" architecture discussed for this RTS.

This document describes what `EntityContext` should own, what feature contexts should own, and how the game should be laid out if ECS is centralized into one shared world.

---

## Overview

- `EntityContext` is the runtime owner of all ECS data and ECS execution in the game.
- Feature contexts such as `Unit`, `Enemy`, `Structure`, `Base`, and `Combat` do not own their own ECS worlds.
- Feature contexts contribute schema, archetypes, systems, and queries into `EntityContext`.
- Systems read and write through `EntityContext`, not through other feature worlds.
- Roblox instance ownership, animation, and other visible-object concerns stay outside the ECS kernel and live in `Infrastructure/ECS/` binding modules.

This is the cleaner shape if many entity families interact frequently. It removes cross-world entity translation and reduces the need for proxy resolver chains.

---

## Core Model

### What `EntityContext` is

- The single simulation root for the game.
- The owner of the JECS world.
- The owner of ECS lifecycle and execution order.
- The owner of shared component and tag registration.
- The owner of generic entity creation, destruction, and queries.

### What `EntityContext` is not

- It is not a gameplay bucket.
- It is not a place for unit-only, enemy-only, or structure-only business rules.
- It is not the place to build models, pick animations, or own UI.
- It is not supposed to grow into a giant context-specific helper object.

---

## What `EntityContext` Should Own

- One JECS world for the whole game.
- Shared component and tag registration.
- Entity creation and destruction.
- Deferred destruction flushing.
- Generic component and tag accessors.
- Generic query APIs.
- Archetype or schema registration from feature contexts.
- System registration and phase ticking.
- ECS-to-instance sync scheduling.
- Shared lookup/index helpers only when they are truly generic.

Recommended public surface:

- `CreateEntity`
- `DestroyEntity`
- `MarkForDestruction`
- `FlushDestructionQueue`
- `Get`
- `Set`
- `Add`
- `Remove`
- `Has`
- `Query`
- `RegisterComponent`
- `RegisterTag`
- `RegisterArchetype`
- `RegisterSystem`
- `TickPhase`
- `TickAll`

---

## Shared Core Components

`EntityContext` should own the shared foundation components that most entity families use.

Recommended shared core components:

- `Identity`
- `Ownership`
- `Transform`
- `Health`
- `Lifetime`
- `Target`
- `ModelRef`
- `ActiveTag`
- `DirtyTag`

Rules:

- Put truly cross-cutting state in the shared core.
- Keep feature-specific state out of the shared core.
- Prefer a small stable foundation over a giant grab-bag of generic fields.
- If a component only matters to one feature family, it belongs in the feature schema, not the core.

Good examples of feature-specific components:

- `BuilderAssignment`
- `AttackCooldown`
- `ConstructionProgress`
- `LockOn`
- `Role`
- `CombatAction`

---

## Feature Schema Registration

Use a single registration entry point for feature schemas.

Recommended signature shape:

```lua
EntityContext:RegisterFeatureSchema(featureName: string, schema: FeatureSchema): CompiledFeatureSchema
```

Registration should behave like compilation, not like live gameplay logic.

### What registration should do

- Validate the feature name.
- Validate the schema shape.
- Register shared and feature-specific components.
- Register shared and feature-specific tags.
- Resolve archetype `Extends` chains.
- Build immutable compiled archetype templates.
- Store the compiled schema for later entity creation and queries.

### What registration should not do

- Create live entities.
- Tick systems.
- Start model sync.
- Call into another feature context’s runtime logic.
- Mutate gameplay state outside of ECS metadata registration.

### Recommended feature schema shape

```lua
return {
    FeatureName = "Unit",

    SharedComponents = {
        "Identity",
        "Ownership",
        "Transform",
        "Health",
        "ModelRef",
    },

    Components = {
        BuilderAssignment = {
            Kind = "record",
            Authority = "authoritative",
            Default = {
                TargetStructureEntity = nil,
            },
        },
    },

    Tags = {
        Active = {},
        Dirty = {},
    },

    Archetypes = {
        Builder = {
            Extends = "UnitBase",
            Components = {
                BuilderAssignment = true,
            },
        },
    },
}
```

### Registration rule

- Feature schemas declare what they need.
- `EntityContext` decides how they are stored.
- The compiled result is the only runtime form used after registration.

---

## What Feature Contexts Should Do

Feature contexts become schema and behavior contributors, not ECS owners.

### Unit

- Define unit-specific components and tags.
- Define unit archetypes and spawn schemas.
- Define unit systems and unit queries.
- Own unit gameplay commands and queries that are not ECS kernel responsibilities.
- Own unit instance-binding or visual helpers only if the unit truly needs them.
- Extend the shared core archetypes instead of repeating core data in every unit archetype.

### Enemy

- Define enemy-specific components and tags.
- Define enemy archetypes.
- Define enemy systems and enemy queries.
- Own enemy gameplay behavior and runtime policy.
- Extend the shared core archetypes where enemy entities share the same foundation.

### Structure

- Define structure-specific components and tags.
- Define structure archetypes.
- Define structure systems and structure queries.
- Own structure instance-binding or runtime helpers as needed.
- Extend the shared core archetypes where structure entities share the same foundation.

### Base

- Define base-specific components, tags, and archetypes.
- Define base systems and queries.
- Own base-specific gameplay logic.
- Use the same shared core foundation when base entities participate in the shared ECS world.

### Combat

- Define combat systems, combat events, and combat runtime rules.
- Query and mutate shared ECS state through `EntityContext`.
- Do not own a separate ECS world.
- Prefer shared-core queries over feature-specific world bridges.

---

## Instance Binding Registration

Use a separate registration path for server-side instance binding rules.

Recommended signature shape:

```lua
EntityContext:RegisterInstanceBinding(featureName: string, binding: InstanceBinding): CompiledInstanceBinding
```

This is the contract for server-side model or instance ownership.

### What instance binding should do

- Describe what Roblox asset or builder to use for the feature.
- Describe where the instance should be parented.
- Describe what baseline attributes or tags should be stamped.
- Describe any static model setup needed after clone or build.
- Describe how the instance maps back to the ECS entity.

### What instance binding should not do

- Create or mutate ECS simulation state.
- Run gameplay logic.
- Decide combat, movement, or targeting behavior.
- Replace the feature schema.
- Replace sync or client discovery.

### Recommended instance binding shape

```lua
return {
    FeatureName = "Unit",

    ParentFolderName = "Units",

    ResolveAsset = function(unitData)
        return "rbxassetid://123456"
    end,

    BuildAttributes = function(entityId, entitySnapshot)
        return {
            EntityId = tostring(entityId),
            UnitId = entitySnapshot.Identity.UnitId,
            OwnerId = entitySnapshot.Ownership.OwnerId,
        }
    end,

    BuildTags = function()
        return {
            Active = true,
        }
    end,

    PrepareInstance = function(instance, entityId, entitySnapshot)
        -- static visual setup only
    end,
}
```

### Registration rule

- Feature contexts declare instance binding rules.
- `EntityContext` owns instance creation and cleanup.
- The compiled binding is the only runtime form used after registration.

### Public `EntityContext` surface

The shared ECS kernel should expose a small public API around binding:

```lua
RegisterFeatureSchema(featureName: string, schema: FeatureSchema): CompiledFeatureSchema
RegisterInstanceBinding(featureName: string, binding: InstanceBinding): CompiledInstanceBinding
CreateEntity(archetypeName: string, payload: { [string]: any }): number
DestroyEntity(entityId: number): ()
BindInstance(entityId: number): Model?
UnbindInstance(entityId: number): ()
```

Public method responsibilities:

- `RegisterFeatureSchema` compiles and stores the feature schema and archetypes.
- `RegisterInstanceBinding` compiles and stores the feature instance-binding contract.
- `CreateEntity` creates the ECS entity first, then queues or performs instance binding when needed.
- `DestroyEntity` removes the ECS entity and ensures the bound instance is cleaned up.
- `BindInstance` exposes the explicit bind path for cases where binding should happen immediately.
- `UnbindInstance` removes the bound instance without destroying the ECS entity when a remap or deferred respawn is needed.

### Runtime methods inside `EntityContext`

The server-side ECS kernel should execute instance binding through a small set of internal methods:

```lua
_GetDefaultInstanceBinding(): CompiledInstanceBinding
_ResolveInstanceBinding(featureName: string): CompiledInstanceBinding?
_ResolveInstanceFolder(binding: CompiledInstanceBinding, snapshot: InstanceSnapshot): Instance?
_BuildInstanceSnapshot(entityId: number): InstanceSnapshot?
_QueueInstanceBind(entityId: number): ()
_BindInstance(entityId: number): Model?
_UnbindInstance(entityId: number): ()
```

Method responsibilities:

- `_GetDefaultInstanceBinding()` returns the shared baseline binding behavior used by every entity family.
- `_ResolveInstanceBinding(featureName)` returns the compiled feature binding for the entity family or `nil` if the entity does not need a visible object.
- `_ResolveInstanceFolder(binding, snapshot)` picks the target parent container in `Workspace` for the instance.
- `_BuildInstanceSnapshot(entityId)` gathers the read-only component data needed by binding.
- `_QueueInstanceBind(entityId)` defers binding until the chosen ECS phase if binding should not happen immediately.
- `_BindInstance(entityId)` runs the shared bind pipeline and applies feature overrides.
- `_UnbindInstance(entityId)` removes the instance, clears the link, and performs any binding cleanup.

Suggested internal data shape:

```lua
type InstanceSnapshot = {
    EntityId: number,
    FeatureName: string,
    ArchetypeName: string,
    Identity: any?,
    Ownership: any?,
    Health: any?,
    Transform: any?,
    ModelRef: any?,
    FeatureData: { [string]: any },
}
```

Shared bind pipeline:

1. Build a read-only snapshot from ECS.
2. Resolve the shared base binding and the feature binding.
3. Resolve or clone the instance template.
4. Compute the final instance name.
5. Apply default attributes and tags.
6. Apply feature-specific attributes and tags.
7. Run the feature `PrepareInstance` hook.
8. Parent the instance into the target folder.
9. Store the entity-to-instance link.

---

## Instance Binding Flow

This is the intended action flow for instance ownership.

### Step 1: feature context registers the binding

`UnitContext` passes a binding table into `EntityContext`.

```lua
EntityContext:RegisterInstanceBinding("Unit", UnitInstanceBinding)
```

### Step 2: `EntityContext` compiles the binding

`EntityContext` validates and freezes the binding:

- checks required fields
- stores the parent folder name
- stores the asset resolver
- stores baseline attribute/tag builders
- stores the prepare hook

### Step 3: entity is created from schema

The ECS entity is created first from the compiled archetype.

### Step 4: instance is created from binding

`EntityContext` uses the compiled instance binding to:

- clone or build the Roblox model
- parent it to the correct folder
- stamp initial attributes and tags
- run the feature-specific prepare hook
- bind the instance back to the entity

### Step 5: sync keeps them aligned

After bind:

- ECS systems continue to own simulation truth
- the instance layer owns the visible Roblox object
- sync updates the visible subset when ECS changes
- cleanup removes the instance when the entity is destroyed

### Step 6: `EntityContext` keeps the bind lifecycle centralized

The instance bind and unbind steps stay inside the shared ECS kernel:

- feature contexts provide the binding rules
- `EntityContext` executes the binding lifecycle
- `EntityContext` owns the entity-to-instance link
- feature contexts do not run a parallel instance factory
- feature contexts do not own separate world services for binding

---

## Archetype Extends

Use `Extends` as the inheritance-like feature for archetypes.

This is not class inheritance. It is a preset merge rule.

### Recommended rules

- `Extends` points to one parent archetype only.
- Parent archetypes are resolved before child archetypes.
- Child archetypes inherit the parent component and tag set.
- Child archetypes may override default payload values.
- Child archetypes may add new components and tags.
- Child archetypes should not remove core components unless the entity family truly does not need them.

### Example

```lua
Archetypes = {
    BaseEntity = {
        Components = {
            Identity = true,
            Ownership = true,
            Transform = true,
            Health = true,
        },
        Tags = {
            Active = true,
        },
    },

    UnitBase = {
        Extends = "BaseEntity",
        Components = {
            Target = true,
            PathState = true,
        },
    },

    BuilderUnit = {
        Extends = "UnitBase",
        Components = {
            BuilderAssignment = {
                TargetStructureEntity = nil,
            },
        },
    },
}
```

### Merge rule

- Parent defaults are applied first.
- Child defaults are applied second.
- Caller payload overrides are applied last when creating the entity.
- The final entity should always be fully initialized before it is returned.

---

## Action Flow Example

This is the intended runtime path from schema declaration to live entity creation.

### Step 1: feature schema is declared

`ReplicatedStorage/Contexts/Unit/Schema/UnitSchema.lua` defines the unit contract.

```lua
return {
    FeatureName = "Unit",

    Components = {
        BuilderAssignment = {
            Authority = "authoritative",
            Default = {
                TargetStructureEntity = nil,
            },
        },
    },

    Archetypes = {
        UnitBase = {
            Extends = "BaseEntity",
            Components = {
                PathState = true,
                Target = true,
            },
        },

        Builder = {
            Extends = "UnitBase",
            Components = {
                BuilderAssignment = true,
            },
        },
    },
}
```

### Step 2: feature context registers the schema

`UnitContext` passes the schema into `EntityContext` during startup.

```lua
EntityContext:RegisterFeatureSchema("Unit", UnitSchema)
```

### Step 3: `EntityContext` compiles the schema

`EntityContext` resolves the registration into a frozen runtime form:

- shared core components are registered once
- unit-specific components are registered once
- tags are registered once
- `Extends` chains are flattened into compiled archetype templates
- the compiled schema is stored for later entity creation and queries

### Step 4: the caller creates an entity by archetype

`UnitContext` or another server caller creates a builder unit through the compiled archetype.

```lua
local entity = EntityContext:CreateEntity("Unit.Builder", {
    Identity = {
        UnitGuid = "unit_001",
        UnitId = "Builder",
    },
    Ownership = {
        OwnerKind = "Player",
        OwnerId = "123",
    },
    Health = {
        Hp = 100,
        MaxHp = 100,
    },
})
```

### Step 5: `EntityContext` applies the merge

The runtime merge happens in this order:

1. `BaseEntity` defaults are applied.
2. `UnitBase` defaults are applied.
3. `Builder` defaults are applied.
4. Caller payload overrides are applied.
5. The entity is returned fully initialized.

The final entity contains the shared core state plus the builder-specific state without requiring the caller to manually set each component every time.

### Step 6: systems query the same world

After creation, systems use the same shared world through `EntityContext`:

- unit systems update unit-specific state
- combat systems query shared health, target, and ownership data
- sync systems project the final state to instances

No parallel unit world is needed for this flow.

---

## Recommended Responsibilities By Layer

### `EntityContext`

- ECS kernel
- world ownership
- schema registration
- entity lifecycle
- queries and mutation APIs
- phase scheduling
- shared sync dispatch
- core component registration

### Feature contexts

- domain meaning
- component and archetype definitions
- domain systems
- feature-specific queries
- gameplay orchestration that is not world ownership

### Instance binding modules

- model creation
- model binding
- attribute/tag projection
- model cleanup
- optional polling from model back into ECS when the feature truly needs it

---

## Sync Guidance

- `EntityContext` should own the ECS sync schedule and the instance-bind queue.
- Feature contexts should not create their own ECS world services.
- If a feature needs a Roblox model bridge, keep it as a thin instance-binding module in `Infrastructure/ECS/`, not a second ECS owner.
- If a feature does not need a visible model, do not create an instance-binding module for it.
- If a feature needs visible-object state but not ECS mutation, keep that logic in the instance-binding module, not in a second ECS stack or separate layer.

Practical default:

- `UnitContext` should not have `UnitECSWorldService`.
- `UnitContext` should only keep an instance-binding module if units still need a unit-specific model lifecycle.
- If `EntityContext` also owns sync dispatch, the unit-specific module should only register what it needs, not run a parallel ECS sync stack.
- Unit archetypes should usually extend the shared entity core archetypes instead of restating the foundation fields.

---

## Client Replication Guidance

- Use one central client replication runtime that mirrors the shared entity world.
- Keep server replication minimal and transport-focused.
- Put entity-type filtering and lookup features on the client runtime.
- Do not create per-feature replication transports when all entities share one server world.

Recommended generic client query surface:

```lua
GetByFeature(featureName: string): { any }
GetByArchetype(archetypeName: string): { any }
GetByTag(tagName: string): { any }
GetByIdentity(featureName: string, identityKey: string): any?
ObserveByFeature(featureName: string, callback: (entity: any) -> ()): () -> ()
ObserveByArchetype(archetypeName: string, callback: (entity: any) -> ()): () -> ()
```

Guidelines:

- Avoid `GetUnits`, `GetStructures`, or other typed getters in the central client.
- Callers should provide `featureName`, `archetypeName`, or identity keys instead.
- Feature modules can wrap the generic API locally when needed, but the shared runtime stays generic.

---

## Consumers

These are the main users of `EntityContext`:

- `UnitContext`
- `EnemyContext`
- `StructureContext`
- `BaseContext`
- `CombatContext`
- `RunContext` when it needs entity-level state
- `WaveContext` when it needs to spawn or query simulation entities

They should treat `EntityContext` as the ECS runtime API, not as a dependency to bypass with their own worlds.

---

## Folder Layout

Recommended layout for a centralized ECS architecture:

```text
src/
  ServerScriptService/
    Contexts/
      Entity/
        EntityContext.lua
        Infrastructure/
          ECS/
            EntityWorldService.lua
            EntityComponentRegistry.lua
            EntityEntityFactory.lua
            EntitySystemRegistry.lua
          Sync/
            EntitySyncService.lua
          ECS/
            EntityInstanceBinding.lua
      Unit/
        UnitContext.lua
        Application/
        Domain/
        Infrastructure/
          ECS/
            UnitSchema.lua
            UnitSystems.lua
            UnitInstanceBinding.lua
          Runtime/
      Enemy/
        EnemyContext.lua
        Application/
        Domain/
        Infrastructure/
          ECS/
            EnemySchema.lua
            EnemySystems.lua
            EnemyInstanceBinding.lua
          Runtime/
      Structure/
        StructureContext.lua
        Application/
        Domain/
        Infrastructure/
          ECS/
            StructureSchema.lua
            StructureSystems.lua
            StructureInstanceBinding.lua
          Runtime/
      Combat/
        CombatContext.lua
        Application/
        Domain/
        Infrastructure/
          BehaviorSystem/
          Runtime/
```

Notes on the layout:

- `Entity/Infrastructure/ECS/` is the only place that owns the actual world and entity mutation surface.
- Feature `Infrastructure/ECS/` folders become schema, system, and instance-binding modules, not separate world owners.
- Instance-binding modules stay feature-local if the feature truly owns a model lifecycle.
- `Combat` should stay a behavior/runtime consumer of shared ECS state, not an ECS owner.

---

## AI Runtime Registration

`EntityContext` should be the registration owner for AI actor types and AI actor entities.

Current-state issue:

- Feature contexts call `CombatContext:RegisterActorType` and `CombatContext:RegisterCombatActor` directly.
- Resolver and proxy factories capture feature factories and other context services.

Target registration flow:

1. Feature context registers AI actor type modules through `EntityContext`.
2. `EntityContext` stores and compiles actor-type definitions.
3. Feature context registers actor entities through `EntityContext`.
4. `EntityContext` resolves runtime profile + resolver factories for the entity.
5. `EntityContext` forwards the compiled actor payload to combat runtime registration.

Recommended `EntityContext` API:

```lua
RegisterAIActorType(payload: {
    ActorType: string,
    Conditions: { [string]: any },
    Commands: { [string]: any },
    Executors: { [string]: any },
    ResolveProfile: (entityContext: any, entity: number) -> any,
    CreateFactsResolver: (entityContext: any) -> any,
    CreateServicesResolver: (entityContext: any, runtimeServices: any) -> any,
}): ()

RegisterAIEntity(entity: number, actorType: string): string
UnregisterAIEntity(entity: number): boolean
```

Registration ownership rules:

- Feature contexts provide behavior modules, profile resolvers, and resolver factories.
- `EntityContext` performs actor registration and unregistration lifecycle.
- `EntityContext` owns entity-to-actor-handle mapping.
- `CombatActorRegistryService` remains runtime execution orchestration.
- Resolver dependencies should consume `EntityContext` query and mutation APIs, not cross-context factories.

---

## CombatContext AI Integration

`CombatContext` should consume AI registrations through `EntityContext`, not through feature contexts directly.

Setup flow:

1. `CombatContext` initializes runtime services (`CombatActorRegistryService`, behavior runtime service, loop service).
2. `CombatContext` passes runtime registration hooks to `EntityContext`.
3. `EntityContext` handles `RegisterAIActorType` and `RegisterAIEntity` calls from feature contexts.
4. `EntityContext` forwards compiled actor type and actor payloads to combat runtime registration.
5. `CombatContext` executes ticks and calls adapter callbacks from registered actors.

Recommended boundary:

- `CombatContext` owns runtime execution.
- `EntityContext` owns actor registration lifecycle and entity-to-actor mapping.
- Feature contexts own actor-type definitions and resolver/profile modules.

Recommended combat-facing interface exposed to `EntityContext`:

```lua
RegisterActorType(payload: {
    ActorType: string,
    Conditions: { [string]: any },
    Commands: { [string]: any },
    Executors: { [string]: any },
    SemanticRequirements: any?,
}): Result.Result<boolean>

RegisterCombatActor(payload: {
    ActorType: string,
    ActorHandle: string,
    BehaviorDefinition: any,
    TickInterval: number,
    Adapter: any,
}): Result.Result<string>

UnregisterCombatActor(actorHandle: string): Result.Result<boolean>
```

Operational rule:

- `CombatContext` should never need to resolve `UnitContext`, `EnemyContext`, or `StructureContext` for actor registration.
- It should receive fully built actor registration payloads from `EntityContext`.

---

## AI Resolver Contract

`EntityContext` should enforce a stable resolver contract for every AI actor type.

Recommended registration callbacks:

```lua
ResolveProfile(entityContext: any, entity: number): {
    BehaviorDefinition: any,
    TickInterval: number,
    VariantId: string?,
}?

CreateFactsResolver(entityContext: any): {
    BuildFacts: (entity: number, currentTime: number) -> { [string]: any },
    Invalidate: ((entity: number) -> ())?,
}?

CreateServicesResolver(entityContext: any, runtimeServices: any): {
    BuildServices: (entity: number, currentTime: number, tickId: number?, frameContext: any?) -> { [string]: any },
    Invalidate: ((entity: number) -> ())?,
    Cleanup: ((entity: number) -> ())?,
}?
```

Adapter callbacks built by `EntityContext`:

```lua
IsActive(): boolean
BuildFacts(currentTime: number): { [string]: any }
BuildServices(currentTime: number, tickId: number?, frameContext: any?): { [string]: any }
OnCancel(): ()
OnRemoved(): ()
OnActionStateChanged(actionState: any): ()
```

Contract rules:

- Resolvers should be pure data/query adapters over `EntityContext`.
- Resolvers should not own direct cross-context factory dependencies.
- Returned facts and services should preserve current behavior-runtime shapes.
- Missing resolvers should degrade safely to empty tables.

---

## AI Runtime Data Contract

AI actor entities should expose a minimum shared ECS contract.

Required fields:

- `AIActorType` or equivalent actor-type marker.
- `RuntimeProfileId` or equivalent profile variant marker.
- `ActiveTag` and lifecycle validity markers.
- `ActionState` storage used by behavior runtime.
- `BehaviorConfig` or `TickInterval` source.

Common optional fields:

- `Target`
- `CombatAction`
- `AttackCooldown`
- `PathState`
- `LockOn`

Rules:

- Runtime profile resolution should depend on ECS data, not context-local state.
- Action state transitions should be persisted through ECS-owned components.
- Feature-specific components remain feature-owned but queryable through `EntityContext`.

---

## AI Tick Phase Order

Use explicit phase boundaries so AI execution is deterministic.

Recommended order:

1. Sense phase:
- build facts using `BuildFacts`.
- validate or refresh target state.

2. Decide phase:
- evaluate behavior tree or decision graph.
- set pending action intent.

3. Commit phase:
- commit action transitions and action-state updates.
- write intent components to ECS.

4. Execute phase:
- run executor side effects (movement requests, attack requests, build requests).
- update cooldown and action timestamps.

5. Cleanup phase:
- clear stale intents.
- flush deferred removals and cache invalidations.

Rules:

- `CombatActorRegistryService` owns actor runtime evaluation cadence.
- `EntityContext` owns phase scheduling and ECS write boundaries.
- AI writes should occur in declared phases only.

---

## AI Caching Policy

Caching should be actor-scoped and invalidation-driven.

Recommended caches:

- facts cache keyed by `entity`.
- services cache keyed by `entity`.
- optional cheap fact-group cache keyed by `entity + group`.

Invalidation triggers:

- actor unregistered or destroyed.
- relevant component/tag write detected.
- explicit resolver invalidation call.
- max cache age exceeded.

Rules:

- facts cache should use short TTL.
- service cache can persist longer but must reset on lifecycle events.
- cache storage should be owned by `EntityContext` AI registration records, not scattered across feature contexts.

---

## AI Failure and Fallback Policy

Runtime failures should degrade safely without breaking the frame.

Registration-time failures:

- invalid actor type payload should reject registration.
- missing profile resolver result should reject actor registration.
- missing behavior definition should reject actor registration.

Tick-time failures:

- `BuildFacts` failure should return `{}` and log structured runtime error.
- `BuildServices` failure should return `{}` and log structured runtime error.
- callback failures (`OnCancel`, `OnRemoved`, `OnActionStateChanged`) should be best-effort and not break loop.

Rules:

- keep runtime failure isolation per actor.
- retain actor record unless hard-invalid state requires removal.
- error reporting should include actor type, handle, runtime id, and failure stage.

---

## AI Unregister Semantics

Unregister should follow a strict cleanup order.

Recommended order:

1. resolve actor handle from `entity -> actorHandle` mapping.
2. call combat runtime unregister using handle.
3. call resolver cleanup hooks (`Cleanup`, `Invalidate`).
4. clear facts/services caches for entity.
5. clear mapping entries.
6. clear runtime-owned lock or movement side effects if configured.

Rules:

- unregister should be idempotent.
- missing mappings should return false or no-op safely.
- cleanup must run even when combat unregister returns a non-fatal failure.

---

## AI Migration Mapping

Map existing modules to centralized AI registration roles.

Current to target mapping:

- `UnitCombatAdapterService`
- becomes feature registration contributor that calls `EntityContext:RegisterAIActorType` and `EntityContext:RegisterAIEntity`.

- `UnitRuntimeProfiles`
- remains profile provider; consumed by `ResolveProfile` callback.

- `UnitFactsResolverFactory`
- remains facts resolver module; dependency surface changes to `EntityContext`.

- `UnitServiceProxyResolverFactory`
- remains services resolver module; dependencies change to `EntityContext` and shared runtime services.

- `UnitMovementProxyResolverFactory`
- becomes movement services helper bound through centralized services resolver.

Migration rule:

- keep behavior definitions and executor contracts stable first.
- swap registration ownership and resolver dependencies before rewriting behavior logic.

---

## EntityContext State Machine

`EntityContext` should use a state machine to enforce setup order and prevent partial runtime initialization.

Recommended states:

1. `Uninitialized`
2. `RegisteringECS`
3. `CompilingECS`
4. `ReadyForAIRegistration`
5. `RegisteringAI`
6. `Running`
7. `ShuttingDown`
8. `Destroyed`

Required transition rules:

- ECS setup must complete before AI actor-type registration.
- AI actor-type registration must complete before AI entity registration.
- runtime tick and replication hooks can only run in `Running`.
- unregister and cleanup logic must still run in `ShuttingDown`.

Recommended startup sequence:

1. enter `RegisteringECS`
2. register shared components/tags
3. register feature schemas/archetypes/systems
4. compile schema metadata and validate
5. enter `ReadyForAIRegistration`
6. register AI actor types
7. finalize runtime services and sync hooks
8. enter `Running`

If startup fails:

- transition to `ShuttingDown`
- run cleanup/unregister for partial registrations
- transition to `Destroyed`

---

## EntityContext API Contract

Public API should be explicit and result-oriented.

Recommended methods:

```lua
Init(registry: any, name: string): Result.Result<boolean>
Start(): Result.Result<boolean>
Destroy(): Result.Result<boolean>

RegisterFeatureSchema(featureName: string, schema: FeatureSchema): Result.Result<CompiledFeatureSchema>
RegisterInstanceBinding(featureName: string, binding: InstanceBinding): Result.Result<CompiledInstanceBinding>
RegisterSystem(phase: string, system: any): Result.Result<boolean>

CreateEntity(archetypeName: string, payload: { [string]: any }): Result.Result<number>
DestroyEntity(entity: number): Result.Result<boolean>
MarkForDestruction(entity: number): Result.Result<boolean>
FlushDestroyQueue(): Result.Result<number>

RegisterAIActorType(payload: any): Result.Result<boolean>
RegisterAIEntity(entity: number, actorType: string): Result.Result<string>
UnregisterAIEntity(entity: number): Result.Result<boolean>

BindInstance(entity: number): Result.Result<Model?>
UnbindInstance(entity: number): Result.Result<boolean>
```

Contract rules:

- methods should reject invalid state-machine transitions.
- methods should validate arguments and report structured failures.
- query helpers should remain non-throwing where possible.

---

## Ownership Map

File-level ownership should be explicit to avoid kernel drift.

- `EntityContext`
- owns ECS world lifecycle, schema compile, instance/AI registration lifecycle, phase execution.

- `CombatContext`
- owns behavior runtime execution and actor tick orchestration.

- Feature contexts (`Unit`, `Enemy`, `Structure`, `Base`)
- own schema definitions, resolver/profile modules, and registration calls into `EntityContext`.

- Resolver/profile modules
- remain feature-local, but consume `EntityContext` query and mutation APIs only.

---

## Migration Sequence

Use this order to avoid breaking runtime:

1. create `EntityContext` state machine and core API skeleton.
2. move shared ECS registration into `EntityContext`.
3. register feature schemas/archetypes into `EntityContext`.
4. centralize instance binding registration and lifecycle.
5. add central AI actor-type registration (`RegisterAIActorType`).
6. route feature actor entity registration through `RegisterAIEntity`.
7. refactor facts/services resolvers to consume `EntityContext` APIs.
8. centralize server replication registration surface.
9. centralize client replication query surface.
10. remove direct feature -> combat actor registration paths.

Safety rule:

- migrate one actor type first (for example `Unit`) before moving all features.

---

## Acceptance Checks

Use these checks before considering migration complete:

1. state machine correctness
- invalid transitions are rejected.
- startup cannot reach `Running` before ECS compile and AI actor-type registration.

2. ECS centralization
- no feature context owns a separate ECS world for shared entities.
- all entity create/destroy paths route through `EntityContext`.

3. AI registration centralization
- feature contexts do not call `CombatContext:RegisterActorType` directly.
- feature contexts do not call `CombatContext:RegisterCombatActor` directly.
- actor registration/unregistration is routed through `EntityContext`.

4. resolver dependency hygiene
- facts/services resolvers do not depend on cross-context entity factories.
- resolvers use `EntityContext` query/mutation APIs.

5. runtime behavior integrity
- actor tick cadence and action transitions still function.
- cache invalidation and unregister cleanup behave correctly.

6. replication integrity
- server bootstrap/reliable/unreliable/entity replication still hydrates clients.
- client generic queries return correct entities by feature/archetype/tag/identity.

---

## Lifecycle Flow

1. `EntityContext` initializes the shared world.
2. Feature contexts register their components, tags, archetypes, and systems.
3. `EntityContext` ticks systems in declared phase order.
4. Systems query and mutate entities through `EntityContext`.
5. Instance-binding modules project ECS state to Roblox models or read back runtime state when needed.
6. Cleanup and deferred destruction flush at the boundary owned by `EntityContext`.

---

## What This Means For `UnitContext`

- `UnitContext` should not own an ECS world if `EntityContext` is the single ECS kernel.
- `UnitContext` should not have a parallel `UnitECSWorldService`.
- `UnitContext` can still own unit-specific application logic, domain rules, runtime helpers, and model/instance helpers.
- If unit models are still needed, keep only a thin instance-binding module, not a second ECS stack.
- If unit state is fully simulated in `EntityContext`, unit-specific sync code should become registration or projection logic inside the shared ECS pipeline.

---

## Open Questions For The Next Pass

- Which feature-specific data should remain in feature contexts versus move into shared ECS schema?
- Which sync responsibilities should live in `EntityContext` versus feature-local instance-binding modules?
- Which entity families need model ownership at all?
- Which systems should remain feature-local and which should become shared ECS systems?

---

## Summary

- Use one ECS world.
- Put ECS ownership in `EntityContext`.
- Make feature contexts register schema and systems, not worlds.
- Keep instance lifecycle separate from ECS ownership.
- Avoid parallel ECS stacks for `Unit`, `Enemy`, `Structure`, or `Combat`.
