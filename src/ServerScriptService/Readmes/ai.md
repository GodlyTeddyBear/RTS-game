# AI Runtime Overview

The shared AI system is a runtime engine, not a feature owner.

It compiles behavior trees, runs actor frames, stores live actor records, and routes adapter callbacks for registered actors. It does not own entity creation, live model lifecycle, runtime profiles, context-specific behavior definitions, or projection policy. Those stay in the owning bounded contexts such as:

- `UnitContext`
- `StructureContext`
- `EnemyContext`
- `SummonContext`

## Core Rule

The runtime context is a shared system that other contexts hook onto.

The runtime may own:

- runtime construction and shutdown
- shared behavior-tree compilation
- actor-type registration
- queued actor payload handling before runtime start
- live actor registry records
- action-state snapshots
- per-frame adapter routing
- executor dispatch

The runtime must not own:

- context-specific adapters
- context-specific behavior trees or executor packages
- context-specific runtime profiles
- context-specific resolver factories
- ECS entities, model refs, or instance lifecycle
- animation-state projection policy
- context-specific variant selection rules

If a rule depends on a context noun such as `Enemy`, `Structure`, `Unit`, or `Summon`, that rule belongs in the owning context, not in the shared runtime.

## Ownership Map

| Layer | Owns |
|------|------|
| Shared runtime services | startup, frame execution, behavior-tree compilation, actor registry bookkeeping, adapter hook dispatch |
| Owning context | entity creation, instance lifecycle, actor-type payload shape, behavior definitions, runtime profile selection, facts, services, sync projection |
| `Runtime/Profiles/` inside a context | variant selection, tick interval, animation mapping, context-specific fallback policy |
| `Runtime/Resolvers/` inside a context | callback factories, proxy builders, target mapping, context-specific technical adapters |
| Adapter service inside a context | bridge from entity state to shared runtime payloads |

## Shared Runtime Pieces

| Module | Responsibility |
|------|----------------|
| `CombatBehaviorRuntimeService` | Owns runtime startup, behavior compilation, frame execution, and queued-actor registration. |
| `CombatActorRegistryService` | Owns actor-type payloads, live records, action state, tick cadence, and adapter callbacks. |
| `ActorAdapterHook` | Pulls facts and services from the registry for one actor on one frame. |
| Context adapter services | Build context-specific actor payloads and register them with combat. |
| `ActorRegistryBase` | Provides the shared registry indexes used by the combat registry service. |

## Registration Flow

```text
Owning context starts
  -> resolve CombatContext
  -> construct context-owned adapter service
  -> register actor type once with CombatContext

Entity becomes runtime-eligible
  -> owning context creates ECS entity
  -> owning context creates or binds the live instance if needed
  -> owning adapter resolves the context runtime profile
  -> owning adapter builds facts/services callbacks
  -> CombatContext:RegisterCombatActor queues or registers the actor

Shared runtime
  -> validates runtime state
  -> compiles the behavior tree from the owning context payload
  -> stores the live actor record in CombatActorRegistryService
```

## Per-Frame Action Flow

```text
Combat tick fires
  -> CombatBehaviorRuntimeService.RunFrame
  -> runtime selects active actor records from CombatActorRegistryService
  -> ActorAdapterHook requests BuildFacts and BuildServices for one actor
  -> owning adapter reads owning-context state and returns a snapshot
  -> behavior tree evaluates conditions and selects a command or executor
  -> runtime updates action state in the registry
  -> adapter callbacks such as OnActionStateChanged / OnActionResult run
  -> owning context sync service projects action state to the model if needed
```

## Removal Flow

```text
Entity leaves runtime ownership
  -> owning context unregisters the actor handle
  -> CombatContext forwards to the shared registry
  -> live actor record is removed
  -> adapter OnCancel / OnRemoved callbacks run when present
  -> owning context performs any entity or model cleanup it owns
```

## Adapter Boundary

Each adapter service should:

- resolve its own entity factory and context collaborators
- resolve the shared runtime context
- resolve the context runtime profile when an actor registers
- register its actor type once
- register and unregister individual live actors
- provide `IsActive`, `GetActorLabel`, `BuildFacts`, and `BuildServices`
- optionally provide `OnCancel`, `OnRemoved`, `OnActionStateChanged`, or `OnActionResult`

Each adapter service must not:

- become the permanent home for context-specific policy branches
- inline large resolver or callback-construction logic that belongs in `Runtime/Resolvers/`
- duplicate animation or state mapping that belongs in `Runtime/Profiles/`
- assume ownership of ECS lifecycle or model lifecycle

The adapter stays thin. It bridges the owning context into the shared runtime. It does not transfer ownership.

## Behavior And Profile Constraints

Behavior definitions, executor sets, and runtime profiles are owned by the context that owns the actor type.

That means:

- `Enemy` behaviors belong under enemy-owned runtime folders
- `Structure` attack and mining behaviors belong under structure-owned or mining-owned runtime folders
- `Unit` behaviors belong under unit-owned runtime folders
- the shared runtime should not grow a folder of context-specific profiles or behaviors

When a new actor family is added, the shared runtime should need generic extension only. The actor family's specific trees, profiles, resolvers, and adapters should be added in the owning context.

## Constraints And Prohibitions

- Do not put `Enemy`, `Structure`, `Unit`, or similar actor-specific profile data into the shared runtime service layer.
- Do not let the shared runtime own adapter modules for a specific context.
- Do not move context-specific facts-building rules into `CombatBehaviorRuntimeService` or `CombatActorRegistryService`.
- Do not make the shared runtime the place where animation projection policy lives.
- Do not let owning contexts bypass adapters and register raw ECS details directly into the runtime.
- Do not let sync services create behavior definitions or select executor sets.

## Actor-Type Examples

### Unit

`UnitCombatAdapterService` owns the `Unit` actor-type payload and uses unit-owned profiles and resolvers. The shared runtime only executes what the unit context registered.

### Structure

`StructureCombatAdapterService` and `StructureMiningAdapterService` each bridge structure-owned entities into a shared runtime. The shared runtime does not own structure attack policy, structure mining profiles, or structure resolver logic.

### Enemy

`EnemyCombatAdapterService` owns enemy runtime-profile resolution, enemy facts, enemy services, and enemy-specific resolver wiring. The shared runtime remains generic.

### Summon

`SummonCombatAdapterService` owns summon actor registration and any summon-specific runtime payload details, even when it reuses shared nodes or executors.

## Key Files

- [CombatBehaviorRuntimeService.lua](../Contexts/Combat/Infrastructure/Services/CombatBehaviorRuntimeService.lua)
- [CombatActorRegistryService.lua](../Contexts/Combat/Infrastructure/Services/CombatActorRegistryService.lua)
- [ActorAdapterHook.lua](../Contexts/Combat/Infrastructure/BehaviorSystem/Hooks/ActorAdapterHook.lua)
- [ActorRegistryBase](../../ReplicatedStorage/Utilities/ActorRegistryBase/init.lua)
- [AI entry](../../ReplicatedStorage/Utilities/AI/src/init.lua)
- [UnitCombatAdapterService.lua](../Contexts/Unit/Infrastructure/Services/UnitCombatAdapterService.lua)
- [StructureCombatAdapterService.lua](../Contexts/Structure/Infrastructure/Services/StructureCombatAdapterService.lua)
- [StructureMiningAdapterService.lua](../Contexts/Structure/Infrastructure/Services/StructureMiningAdapterService.lua)
- [EnemyCombatAdapterService.lua](../Contexts/Enemy/Infrastructure/Services/EnemyCombatAdapterService.lua)
- [SummonCombatAdapterService.lua](../Contexts/Summon/Infrastructure/Services/SummonCombatAdapterService.lua)
