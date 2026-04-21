# World Isolation Rules

## Core Rules

- One JECS world per bounded context — worlds are never shared across contexts
- Worlds never cross-reference each other — no entity ID from one world is used in another
- Only the Infrastructure layer interacts with JECS directly (world creation, component registration, system ticking)
- Domain and Application layers are fully decoupled from JECS — they call factory and service APIs only
- World lifetime is managed by a dedicated `*ECSWorldService` per context
- Cross-context communication uses domain events or service APIs, never shared world queries

## Layer Boundary

JECS is an infrastructure concern. It must not leak into the Domain or Application layers.

```
Infrastructure  → creates world, registers components, ticks systems, owns factories
Application     → calls factory/service APIs; no JECS imports
Domain          → pure logic; no JECS imports
```

```lua
-- CORRECT: Application layer calls a service API
local enemies = self._enemyService:GetAliveEnemyCount()

-- WRONG: Application layer touches JECS directly
local count = 0
for _ in world:query(components.AliveTag) do count += 1 end
```

## World Ownership

Each bounded context that manages entities owns exactly one world through a dedicated world service. The world service is responsible for:

- Creating the JECS world
- Initializing the component registry
- Constructing all factories
- Constructing and ticking all systems

```lua
-- CORRECT: isolated worlds per context
-- EnemyECSWorldService    → owns EnemyWorld, EnemyComponentRegistry, EnemyEntityFactory
-- StructureECSWorldService → owns StructureWorld, StructureComponentRegistry, StructureEntityFactory

-- WRONG: shared world across contexts
local sharedWorld = Jecs.World.new()
EnemyEntityFactory.new(sharedWorld, ...)
StructureEntityFactory.new(sharedWorld, ...)
```

## Cross-Context Communication

When one context needs information about another context's entities, it goes through a service API or domain event — never through a direct world query.

```lua
-- CORRECT: StructureAttackSystem asks EnemyService for a target
local target = self._enemyService:GetNearestAliveEnemy(position)

-- WRONG: StructureAttackSystem queries the enemy world directly
for entity in enemyWorld:query(enemyComponents.AliveTag) do ... end
```
