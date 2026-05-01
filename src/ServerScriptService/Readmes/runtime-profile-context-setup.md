# Runtime Profile Context Setup

This document explains the current ECS runtime pattern used by `Structure`, `Enemy`, and `Unit`, and how to set up a new context that follows the same shape.

Use this when you want a new bounded context that owns:

- its own ECS world data
- its own live instance lifecycle
- its own combat or behavior adapter wiring
- its own sync projection to model attributes
- variant-specific behavior without growing shared services with `if` chains

The example below uses a new context called `Players`.

## Core Rule

Split responsibilities into four context-owned layers:

1. `EntityFactory`
2. `InstanceFactory`
3. `GameObjectSyncService`
4. `CombatAdapterService`

Then put all variant-specific runtime policy in:

- `Runtime/Profiles/`
- `Runtime/Resolvers/`

The owning context owns these modules. The shared runtime does not.

This keeps the sync service projection-only and keeps the adapter focused on runtime wiring instead of becoming a variant switchboard.

## Ownership Contract

The owning context owns:

- ECS entity creation and mutation
- instance lifecycle
- adapter registration and unregister flows
- behavior definitions and executor packages
- runtime profiles
- resolver factories
- sync projection policy

The shared runtime owns:

- generic runtime startup and shutdown
- generic actor registration bookkeeping
- behavior-tree compilation
- per-frame evaluation
- generic action-state storage and callback dispatch

The shared runtime must not own:

- context-specific adapters
- context-specific profiles
- context-specific behaviors
- context-specific resolver factories

Treat the shared runtime as a system that contexts hook onto, not as the owner of those contexts' actor logic.

## Runtime Flow

The runtime path should look like this:

1. `Context` boots the world service and infrastructure modules.
2. An application command creates the ECS entity in `EntityFactory`.
3. `InstanceFactory` creates and binds the live model when this context owns one.
4. `GameObjectSyncService:RegisterEntity(...)` pushes the first attribute projection.
5. `CombatAdapterService:RegisterActor(...)` or another context-owned adapter registers the entity with the shared runtime.
6. Runtime profiles decide:
   - which behavior tree definition is used
   - which animation state should be projected for each action/state pair
   - whether that animation state loops
   - any role or type-specific tick settings
7. Resolver modules provide context-specific callbacks for hitbox, projectile, movement, or damage systems.
8. The shared runtime evaluates the actor each frame and writes action state back through callbacks.
9. The sync service projects the resulting state back to the live model.

## Registration And Removal Flows

### Register flow

```text
Owning context creates entity
  -> owning instance factory binds live model if needed
  -> owning adapter resolves RuntimeProfileId from config
  -> owning adapter gets BehaviorDefinition + TickInterval from Runtime/Profiles
  -> owning adapter gets proxy and callback builders from Runtime/Resolvers
  -> shared runtime registers or queues the actor
```

### Remove flow

```text
Owning context decides the entity is no longer active
  -> owning adapter unregisters the actor handle
  -> shared runtime removes the live actor record
  -> adapter cleanup callbacks run when present
  -> owning context cleans up its entity and instance state
```

## Folder Layout

Use a layout like this:

```text
Contexts/
  Players/
    PlayersContext.lua
    Application/
      Commands/
      Queries/
    Infrastructure/
      ECS/
        PlayerComponentRegistry.lua
        PlayerEntityFactory.lua
        PlayerECSWorldService.lua
      Persistence/
        PlayerGameObjectSyncService.lua
      Runtime/
        Profiles/
          PlayerRuntimeProfiles.lua
        Resolvers/
          PlayerHitTargetResolverFactory.lua
          PlayerProjectileResolverFactory.lua
      Services/
        PlayerInstanceFactory.lua
        PlayerCombatAdapterService.lua
```

`Persistence/` owns projection and polling.
`Services/` owns runtime helpers and adapter wiring.
`Runtime/Profiles/` owns per-variant runtime selection and animation-state resolution.
`Runtime/Resolvers/` owns callback tables and hit-resolution helpers.

## 1. Define Shared Config And Types

Your config should expose the canonical variant key that selects runtime behavior.

Example:

```lua
PlayerConfig.Classes = table.freeze({
    Ranger = table.freeze({
        RuntimeProfileId = "Ranged",
        MaxHealth = 100,
    }),
    Knight = table.freeze({
        RuntimeProfileId = "Melee",
        MaxHealth = 160,
    }),
})
```

Rules:

- The config key should be stable and data-owned.
- The runtime profile key should be the only thing the adapter or sync service needs to branch on.
- Do not put behavior tree selection logic directly in the adapter once the config already knows the variant.

## 2. Build The Entity Factory

The entity factory owns:

- ECS entity creation
- component reads and writes
- model ref storage
- transform fallback state
- target or combat action component state

It should not own:

- model creation
- workspace parenting
- animation-state projection
- hitbox or projectile callback wiring

For `Players`, create methods such as:

- `CreatePlayer(record)`
- `GetIdentity(entity)`
- `GetClass(entity)`
- `GetCombatAction(entity)`
- `SetCombatAction(entity, action)`
- `GetModelRef(entity)`
- `SetModelRef(entity, model)`
- `QueryActiveEntities()`

## 3. Build The Instance Factory

The instance factory owns:

- asset lookup
- model clone or fallback model creation
- reveal metadata
- workspace parenting
- instance cleanup
- setting baseline attributes like `AnimationState = "Idle"`

It should not own:

- ECS mutation
- behavior tree selection
- dynamic animation-state logic

For `Players`, that usually means:

- `CreatePlayerInstance(entity, className, spawnData...)`
- `DestroyInstance(entity)`
- `DestroyAll()`

## 4. Build The Runtime Profile Module

This is the key abstraction.

A runtime profile module converts the config-selected variant into a frozen runtime profile table and resolves animation state for sync projection.

A profile should hold:

- `BehaviorDefinition`
- `DefaultAnimationState`
- `AnimationByActionIdAndState`
- `LoopingByAnimationState`
- `TickInterval`

Example:

```lua
local PROFILES_BY_ID = table.freeze({
    Ranged = table.freeze({
        BehaviorDefinition = RangerBehavior,
        DefaultAnimationState = "Idle",
        AnimationByActionIdAndState = table.freeze({
            ["Player.Shoot"] = table.freeze({
                Running = "Shoot",
                Committed = "Shoot",
            }),
        }),
        LoopingByAnimationState = table.freeze({
            Idle = true,
            Shoot = false,
        }),
        TickInterval = 0.1,
    }),
})
```

Rules:

- Freeze the registry and nested profile tables.
- Keep the strings that clients already consume stable.
- Add new variants by adding new profiles, not by editing sync conditionals.
- Do not place these profiles under the shared runtime context.

The sync service should not know special cases like:

- `if Class == "Ranger" then ...`
- `if ActionId == "Player.Shoot" then ...`

Move that into the runtime profile module by exposing:

- `GetByVariant(variantId)`
- `ResolveAnimationState(input)`

Locomotion fallback also belongs there if your context has it.

## 5. Build Resolver Modules

Resolver modules extract technical callback-building logic out of adapters.

Resolver modules should own:

- `Create(dependencies)`
- proxy builders
- target mapping helpers
- combat callback tables that do not belong inline in the adapter

Resolver modules should not own:

- entity lifecycle
- context orchestration
- variant policy already owned by `Runtime/Profiles/`

## 6. Build The GameObjectSyncService

The sync service should only:

- read ECS state from `EntityFactory`
- read live runtime action state from the owning runtime source
- resolve the animation state through the runtime profile module
- project attributes to the bound model

It should not:

- create or destroy instances
- mutate ECS
- contain per-class or per-role feature logic
- choose behavior definitions

For `Players`, the sync method should read like:

1. read health, identity, combat action, and movement state
2. resolve animation state through `PlayerRuntimeProfiles.ResolveAnimationState(...)`
3. set model attributes

If you find `PlayerGameObjectSyncService` growing `if className == ...` logic, move that logic back into `Runtime/Profiles/`.

## 7. Build The Combat Adapter

The combat adapter should:

- register the actor type once
- register and unregister individual actors
- build thin runtime service proxies
- resolve the runtime profile and use its `BehaviorDefinition` and `TickInterval`
- wire combat services once through dedicated resolver modules

It should not:

- own all resolver logic inline
- hardcode variant selection rules
- turn into a catch-all file for future special cases
- move context-specific behavior ownership into the shared runtime

For `Players`, this is the right pattern:

```lua
local runtimeProfile = PlayerRuntimeProfiles.GetByVariant(runtimeProfileId)

return combatContext:RegisterCombatActor({
    ActorType = "Player",
    ActorHandle = actorHandle,
    BehaviorDefinition = runtimeProfile.BehaviorDefinition,
    TickInterval = runtimeProfile.TickInterval,
    Adapter = { ... },
})
```

## 8. Extract Combat Resolvers

Any combat callback that is likely to grow should live in `Runtime/Resolvers/`.

Typical extracted modules:

- `PlayerHitTargetResolverFactory.lua`
- `PlayerProjectileResolverFactory.lua`
- `PlayerMeleeResolverFactory.lua`
- `PlayerHealResolverFactory.lua`

Use a simple rule:

- If the adapter method only exists to build a callback table or map a touched part back to an entity, move it into `Resolvers/`.

Standard helper contract:

- helper modules should be `*Factory` modules
- they should expose `Create(dependencies)`
- `Create(...)` should return a callback table
- even single-purpose target mapping resolvers should return a callback table, not a bare function

This keeps the adapter readable and makes future combat additions isolated.

## 9. Connect The Context

In `PlayersContext.lua`, register the modules the same way `Structure` and `Enemy` do:

- component registry
- entity factory
- instance factory
- combat adapter service
- game object sync service

Then in `KnitStart()`:

1. register sync and poll systems
2. set the runtime owner on the adapter
3. register the actor type
4. connect any placement, spawn, or lifecycle events

## 10. Client Animation Presets

If the client uses an animation preset, keep fallback mapping table-driven too.

Bad:

```lua
if state == "AttackBoss" then
    return "Attack"
end
```

Better:

```lua
local ACTION_STATE_CANDIDATES = table.freeze({
    AttackBoss = table.freeze({ "Attack", "attack" }),
})
```

The same principle applies on both server and client:

- variant mapping belongs in tables
- orchestration belongs in services

## Setup Checklist For A New `Players` Context

- [ ] Add canonical config for player classes or roles.
- [ ] Add shared types for identity, health, action, and variant data.
- [ ] Create `PlayerComponentRegistry`.
- [ ] Create `PlayerEntityFactory`.
- [ ] Create `PlayerInstanceFactory`.
- [ ] Create `PlayerRuntimeProfiles`.
- [ ] Create `PlayerGameObjectSyncService`.
- [ ] Create `PlayerCombatAdapterService`.
- [ ] Extract any hit, melee, projectile, or damage resolvers into `Runtime/Resolvers/`.
- [ ] Register the modules in `PlayersContext.lua`.
- [ ] Register sync and poll systems in `KnitStart()`.
- [ ] Keep preset action fallback mapping table-driven on the client side.

## Anti-Patterns To Avoid

- Putting `if Role == ...` logic into `GameObjectSyncService`.
- Putting `if Type == ...` behavior selection into `CombatAdapterService`.
- Adding more private adapter methods that only build callback tables.
- Letting the instance factory mutate ECS.
- Letting the sync service create or destroy models.
- Duplicating animation mapping logic in both adapter and sync.
- Moving context-specific profiles, behaviors, or resolvers into the shared runtime context.

## Current Reference Files

- `Structure`
  - `Infrastructure/Runtime/Profiles/StructureRuntimeProfiles.lua`
  - `Infrastructure/Runtime/Resolvers/StructureHitTargetResolverFactory.lua`
  - `Infrastructure/Runtime/Resolvers/StructureProjectileResolverFactory.lua`
  - `Infrastructure/Persistence/StructureGameObjectSyncService.lua`
  - `Infrastructure/Services/StructureCombatAdapterService.lua`
- `Enemy`
  - `Infrastructure/Runtime/Profiles/EnemyRuntimeProfiles.lua`
  - `Infrastructure/Runtime/Resolvers/EnemyHitTargetResolverFactory.lua`
  - `Infrastructure/Runtime/Resolvers/EnemyMeleeResolverFactory.lua`
  - `Infrastructure/Persistence/EnemyGameObjectSyncService.lua`
  - `Infrastructure/Services/EnemyCombatAdapterService.lua`
- `Unit`
  - `Infrastructure/Runtime/Profiles/UnitRuntimeProfiles.lua`
  - `Infrastructure/Runtime/Resolvers/UnitServiceProxyResolverFactory.lua`
  - `Infrastructure/Persistence/UnitGameObjectSyncService.lua`
  - `Infrastructure/Services/UnitCombatAdapterService.lua`
