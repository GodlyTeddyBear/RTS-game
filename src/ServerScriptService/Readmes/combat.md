# Combat Overview

Combat is a shared runtime layer that runs behavior trees for registered actors. It does not own entity creation, models, or health state. Those stay in the owning contexts:

- `UnitContext`
- `StructureContext`
- `EnemyContext`

Combat owns:

- session state for the active run
- runtime startup and shutdown
- actor-type registration
- actor runtime records
- behavior-tree execution
- animation callback routing
- hitbox and melee resolution services

The owning contexts create entities and models, then hand combat a registration payload through their adapter services. If combat runtime is not ready yet, the payload is queued and compiled later when the runtime starts.

## Layer Map

| Layer | Responsibility |
|------|----------------|
| `CombatContext` | Owns session lifecycle, scheduler wiring, and cross-context combat orchestration. |
| `CombatBehaviorRuntimeService` | Owns the AI runtime, actor-type compilation, and frame execution. |
| `CombatActorRegistryService` | Owns actor records, queued payloads, action state, and adapter callbacks. |
| Actor adapters | Bridge a context-owned entity into combat without transferring entity ownership. |
| Executors | Own one actor action and mutate only through the services passed into them. |

## Combat Setup

```text
Unit / Structure / Enemy context starts
  -> entity factory creates ECS entity
  -> instance factory creates model
  -> sync service registers entity/model
  -> combat adapter registers actor type
  -> spawned entities register as combat actors
      -> queued if runtime is not started yet
      -> compiled immediately if runtime is active

Run starts
  -> CombatContext receives WaveStarted
  -> StartCombat starts the runtime if needed
  -> CombatLoopService creates the active session
  -> queued actor payloads are compiled into runtime records
```

## Enemy Attack Flow

```text
EnemyContext spawns enemy
  -> EnemyEntityFactory creates ECS entity
  -> EnemyInstanceFactory creates model
  -> EnemyGameObjectSyncService registers entity/model
  -> EnemyCombatAdapterService.RegisterActor(entity)
      -> CombatContext.RegisterCombatActor
      -> if runtime not started, queue payload

CombatContext starts combat on wave start
  -> StartCombat
  -> CombatBehaviorRuntimeService.StartRuntime
  -> queued enemy actor payloads are compiled into behavior trees
  -> CombatActorRegistryService stores runtime record

Each combat tick
  -> CombatContext scheduler runs MovementTick
  -> CombatContext movement service advances active movers
  -> CombatContext scheduler runs CombatTick
  -> ProcessCombatTick for active session
  -> CombatBehaviorRuntimeService.RunFrame
  -> registry adapter builds facts/services for each enemy
  -> enemy behavior tree picks AttackStructure / AttackBase / Advance / Idle

Enemy attack executor runs
  -> checks cooldown and target range
  -> waits for animation callback or server timeout
  -> creates attack hitbox through HitboxService
  -> marks enemy as committed

Hitbox resolves
  -> AttackStructureExecutor calls CombatHitResolutionService.ResolveEnemyMeleeHits
  -> service dedupes per hitbox handle
  -> routes damage to StructureContext or BaseContext

If target dies
  -> target context unregisters combat actor
  -> destroys model
  -> deletes ECS entity
```

## Run Lifecycle

```text
Run begins
  -> RunContext emits WaveStarted
  -> CombatContext._OnRunWaveStarted
  -> StartCombat executes
      -> validates wave number
      -> finds primary player
      -> starts combat runtime if needed
      -> creates active combat session for that player

Combat runtime comes up
  -> CombatBehaviorRuntimeService.StartRuntime
      -> merges actor-type nodes, commands, executors
      -> builds AI runtime
      -> registers actor types
      -> compiles any queued actor payloads into runtime records

Actors join combat as they spawn
  -> UnitContext / StructureContext / EnemyContext create ECS entity
  -> create instance/model
  -> set ModelRef
  -> register with sync service
  -> register with CombatContext through adapter
      -> if runtime not started, payload is queued
      -> if runtime started, actor is compiled immediately

Every combat tick
  -> CombatContext scheduler runs MovementTick
  -> CombatContext movement service advances active movers
  -> CombatContext scheduler runs CombatTick
  -> ProcessCombatTick executes for active, unpaused combat sessions
  -> CombatBehaviorRuntimeService.RunFrame
  -> each actor adapter supplies facts + services
  -> behavior tree selects an executor action
  -> executor advances the actor state

Attacks resolve
  -> Structure / Enemy attack executor waits for animation callback or server timeout
  -> CombatContext.HandleAnimationCallback receives client marker
  -> executor activates hitbox or projectile
  -> CombatHitResolutionService dedupes hits and routes damage
  -> StructureContext / BaseContext / EnemyContext apply damage

Entity death or despawn
  -> owning context unregisters the actor from CombatContext
  -> instance is destroyed
  -> ECS entity is deleted
  -> sync state is flushed

Run ends
  -> RunContext emits WaveEnded or RunEnded
  -> CombatContext ends combat
  -> EndCombat clears hitboxes, hit resolution, lock-on, movement, projectiles
  -> combat session is removed from CombatLoopService
  -> contexts run their own cleanup paths
      -> StructureContext cleanup
      -> EnemyContext cleanup
      -> UnitContext cleanup
```

## Key Files

- [CombatContext.lua](../Contexts/Combat/CombatContext.lua)
- [CombatBehaviorRuntimeService.lua](../Contexts/Combat/Infrastructure/Services/CombatBehaviorRuntimeService.lua)
- [CombatActorRegistryService.lua](../Contexts/Combat/Infrastructure/Services/CombatActorRegistryService.lua)
- [CombatHitResolutionService.lua](../Contexts/Combat/Infrastructure/Services/CombatHitResolutionService.lua)
- [UnitCombatAdapterService.lua](../Contexts/Unit/Infrastructure/Services/UnitCombatAdapterService.lua)
- [StructureCombatAdapterService.lua](../Contexts/Structure/Infrastructure/Services/StructureCombatAdapterService.lua)
- [EnemyCombatAdapterService.lua](../Contexts/Enemy/Infrastructure/Services/EnemyCombatAdapterService.lua)
