# AI Runtime Overview

The shared AI system is the combat runtime layer that compiles behavior trees, runs actor frames, and routes adapter callbacks for registered actors. It does not own entity creation, model lifecycle, or health/state storage. Those stay in the owning contexts:

- `UnitContext`
- `StructureContext`
- `EnemyContext`
- `SummonContext`

The AI system owns:

- runtime construction and shutdown
- shared behavior-tree compilation
- actor-type registration
- live actor registry records
- queued actor payloads before runtime start
- action-state snapshots
- per-frame adapter routing
- executor dispatch

Actor adapters bridge a context-owned entity into the AI runtime without transferring ownership of the entity or model. The adapter supplies the facts and services that a behavior tree needs for one tick, while the owning context keeps the authoritative entity state.

## Layer Map

| Layer | Responsibility |
|------|----------------|
| `CombatBehaviorRuntimeService` | Owns AI runtime startup, behavior compilation, frame execution, and queued-actor registration. |
| `CombatActorRegistryService` | Owns actor-type payloads, live records, action state, tick cadence, and adapter callbacks. |
| `ActorAdapterHook` | Pulls facts and services from the registry for one actor on one frame. |
| Context adapter services | Build context-specific actor payloads and register them with combat. |
| `ActorRegistryBase` | Provides the shared registry indexes used by the combat registry service. |

## Runtime Flow

```text
Context starts
  -> adapter service registers actor type with CombatContext
  -> actor payload is queued or registered depending on runtime state

Combat runtime starts
  -> CombatBehaviorRuntimeService.StartRuntime
  -> shared conditions, commands, executors, and hooks are merged
  -> AI.CreateRuntime builds the runtime
  -> actor types are registered with registry adapters
  -> queued actor payloads are compiled into live records

Each combat tick
  -> CombatBehaviorRuntimeService.RunFrame
  -> AI runtime queries the actor adapter
  -> ActorAdapterHook.BuildFacts reads registry facts
  -> ActorAdapterHook.BuildServices reads registry services
  -> behavior tree selects an executor action
  -> registry stores action state and tick timing

When an actor leaves
  -> owning context unregisters the actor handle
  -> registry removes the live record
  -> adapter cleanup callbacks run when present
```

## Actor Registration Flow

```text
Unit / Structure / Enemy / Summon context
  -> entity factory creates ECS entity
  -> instance factory or model sync creates the live instance
  -> adapter service builds a combat payload
  -> CombatContext:RegisterActorType registers the actor type once
  -> CombatContext:RegisterCombatActor queues or registers the actor

CombatBehaviorRuntimeService
  -> validates the runtime exists
  -> builds a behavior tree from the payload
  -> stores the compiled tree in CombatActorRegistryService
```

## Adapter Boundary

Each adapter service keeps the same overall shape:

- resolve its own entity factory or model services
- resolve `CombatContext`
- register its actor type once
- register each live entity as a combat actor
- provide `IsActive`, `GetActorLabel`, `BuildFacts`, and `BuildServices`
- optionally provide `OnCancel`, `OnRemoved`, `OnActionStateChanged`, or `OnActionResult`

The adapter should stay thin. It should read from the owning context and hand the runtime a snapshot, not duplicate combat rules.

## Actor Types

### Unit

`UnitCombatAdapterService` registers the passive `Unit` actor type. It uses `UnitIdleBehavior` and exposes only the basic entity lookup service needed by the runtime.

### Structure

`StructureCombatAdapterService` registers the `Structure` actor type and wires shared combat services for target selection, melee resolution, and projectile handling.

### Enemy

`EnemyCombatAdapterService` registers the `Enemy` actor type, validates its semantic contract and runtime binding, and wires shared combat services for movement, lock-on, melee resolution, and hitbox handling.

### Summon

`SummonCombatAdapterService` registers the `Summon` actor type and reuses the shared combat nodes and executors.

## Key Files

- [CombatBehaviorRuntimeService.lua](../Contexts/Combat/Infrastructure/Services/CombatBehaviorRuntimeService.lua)
- [CombatActorRegistryService.lua](../Contexts/Combat/Infrastructure/Services/CombatActorRegistryService.lua)
- [ActorAdapterHook.lua](../Contexts/Combat/Infrastructure/BehaviorSystem/Hooks/ActorAdapterHook.lua)
- [ActorRegistryBase](../../ReplicatedStorage/Utilities/ActorRegistryBase/init.lua)
- [AI entry](../../ReplicatedStorage/Utilities/AI/src/init.lua)
- [UnitCombatAdapterService.lua](../Contexts/Unit/Infrastructure/Services/UnitCombatAdapterService.lua)
- [StructureCombatAdapterService.lua](../Contexts/Structure/Infrastructure/Services/StructureCombatAdapterService.lua)
- [EnemyCombatAdapterService.lua](../Contexts/Enemy/Infrastructure/Services/EnemyCombatAdapterService.lua)
- [SummonCombatAdapterService.lua](../Contexts/Summon/Infrastructure/Services/SummonCombatAdapterService.lua)
