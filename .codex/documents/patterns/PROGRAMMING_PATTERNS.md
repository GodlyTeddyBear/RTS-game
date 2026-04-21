# Programming Patterns (Gang of Four)

Reference for 23 classical design patterns adapted to this project's Lua/Roblox DDD codebase.

## How to use this document

Read it when designing a non-trivial service interaction or when an existing solution feels overcomplicated. Do not apply patterns preemptively — only reach for one when a specific problem it solves is actually present.

In Lua, several GoF patterns collapse into language idioms (noted below). Prefer the idiom over a full class-based implementation when the problem is simple.

---

## Applicability tiers

- **Applicable** — useful in this codebase as written
- **Lua idiom** — the pattern is valid but collapses to a simpler Lua construct; use the idiom
- **Caution** — use with care; common misuse noted
- **Avoid** — conflicts with DDD principles or this project's architecture

---

## Creational Patterns

### Singleton
**Tier:** Avoid
**Problem:** One instance, global access point.
**Why avoid here:** Singleton is a hidden global — it kills testability and conflicts directly with constructor injection. Every service in this project already receives its dependencies via `.new()`. If you feel the need for a Singleton, inject the shared instance instead.

---

### Factory Method
**Tier:** Applicable
**Problem:** A service needs to create objects but shouldn't be coupled to their concrete type.
**Trigger:** You have an Infrastructure service that creates different entity types based on runtime data, and the creation logic is complex enough to warrant isolation.
**In this codebase:** Lives in the Infrastructure layer. The Application layer calls the factory; the factory returns the created entity or its ID.

```lua
-- Infrastructure/Services/EntityFactory.lua
local EntityFactory = {}
EntityFactory.__index = EntityFactory

function EntityFactory.new(world)
    local self = setmetatable({}, EntityFactory)
    self.World = world
    return self
end

function EntityFactory:CreateEnemy(enemyType: string): number
    local entity = self.World:entity()
    -- attach components based on enemyType
    return entity
end

function EntityFactory:CreateProjectile(projectileType: string): number
    local entity = self.World:entity()
    return entity
end

return EntityFactory
```

**Don't use when:** Creation is a single `world:entity()` call with one component — that doesn't need a factory.

---

### Abstract Factory
**Tier:** Applicable (rare)
**Problem:** You need to create families of related objects and the client should never reference concrete types.
**Trigger:** Two or more Factory Methods share a common interface and the Application layer needs to swap between them (e.g., a test factory vs a real factory).
**In this codebase:** Define an interface type (`IEntityFactory`) in ReplicatedStorage/Types, inject it into Application services.

**Don't use when:** You only have one concrete factory. Abstract Factory is for swappability, not abstraction for its own sake.

---

### Builder
**Tier:** Applicable
**Problem:** Constructing a complex object that has many optional parts, and telescoping constructors become unreadable.
**Trigger:** A domain result object or config has 5+ fields where most are optional, and calling `.new(a, b, nil, nil, c, nil, d)` is error-prone.

```lua
-- Domain result with many optional fields — use Builder
local CombatResultBuilder = {}
CombatResultBuilder.__index = CombatResultBuilder

function CombatResultBuilder.new()
    local self = setmetatable({}, CombatResultBuilder)
    self._data = {}
    return self
end

function CombatResultBuilder:WithDamage(amount: number)
    self._data.Damage = amount
    return self  -- fluent: allows chaining
end

function CombatResultBuilder:WithStatusEffect(effect: string)
    self._data.StatusEffect = effect
    return self
end

function CombatResultBuilder:Build()
    return table.freeze(self._data)
end

-- Usage in Domain service:
local result = CombatResultBuilder.new()
    :WithDamage(42)
    :WithStatusEffect("Poison")
    :Build()
```

**Don't use when:** The object has 3 or fewer fields — just use a table literal.

---

### Prototype
**Tier:** Lua idiom
**Problem:** Create new objects by cloning an existing instance instead of constructing from scratch.
**Lua idiom:** This is just `table.clone()` or the `deepClone` utility already used in Infrastructure sync services. No class needed.
**Caution:** Always be aware of shallow vs deep copy. The project's `deepClone` utility handles nested tables correctly — prefer it over `table.clone()` when the source has nested state.

---

## Structural Patterns

### Adapter
**Tier:** Applicable
**Problem:** An external library or system has an interface that doesn't match what your services expect.
**Trigger:** You're wrapping a third-party package (ProfileStore, JECS, Blink) so the rest of the codebase never references it directly. If the library changes, only the adapter changes.
**In this codebase:** Lives in the Infrastructure layer. The Application layer calls the adapter's clean interface; the adapter translates to the library's API.

```lua
-- Infrastructure/Services/ProfileStoreAdapter.lua
local ProfileStoreAdapter = {}
ProfileStoreAdapter.__index = ProfileStoreAdapter

function ProfileStoreAdapter.new(store)
    local self = setmetatable({}, ProfileStoreAdapter)
    self.Store = store
    return self
end

function ProfileStoreAdapter:LoadProfile(userId: number)
    -- Translates to ProfileStore's API — caller never sees it
    return self.Store:StartSessionAsync("Player_" .. userId, {
        Cancel = function() return false end,
    })
end

return ProfileStoreAdapter
```

---

### Bridge
**Tier:** Applicable (rare)
**Problem:** You have two independently varying dimensions (e.g., entity type × sync strategy) and want to avoid a Cartesian product of classes.
**Trigger:** You find yourself wanting `EnemySyncService`, `BossSyncService`, `NPCSyncService` — all doing the same sync logic with different entity shapes. Bridge separates the "what to sync" from "how to sync."
**Don't use when:** You only have one varying dimension. Bridge adds abstraction that only pays off at 2×2 or larger combinations.

---

### Composite
**Tier:** Applicable
**Problem:** You have part-whole tree structures and want to treat leaves and composites uniformly.
**Trigger:** Building a skill tree, quest system, or UI component tree where individual items and groups of items need the same interface.

```lua
-- Both a single skill and a skill group respond to :IsUnlocked()
local SkillNode = {}
SkillNode.__index = SkillNode

function SkillNode.new(id: string)
    local self = setmetatable({}, SkillNode)
    self.Id = id
    self.Children = {}
    return self
end

function SkillNode:Add(child)
    table.insert(self.Children, child)
end

function SkillNode:IsUnlocked(unlockedIds: { string }): boolean
    if #self.Children == 0 then
        -- Leaf: check self
        return table.find(unlockedIds, self.Id) ~= nil
    end
    -- Composite: all children must be unlocked
    for _, child in self.Children do
        if not child:IsUnlocked(unlockedIds) then
            return false
        end
    end
    return true
end
```

---

### Decorator
**Tier:** Applicable
**Problem:** Add responsibilities to an object dynamically without subclassing.
**Trigger:** You want to wrap a service with logging, caching, or rate-limiting behavior without modifying the service itself.
**In this codebase:** Wrap at the Infrastructure or Application layer boundary. The decorator implements the same interface as the wrapped service.

```lua
-- Wraps any validator with rate-limit checking
local RateLimitedValidator = {}
RateLimitedValidator.__index = RateLimitedValidator

function RateLimitedValidator.new(innerValidator, rateLimiter)
    local self = setmetatable({}, RateLimitedValidator)
    self.Inner = innerValidator
    self.RateLimiter = rateLimiter
    return self
end

function RateLimitedValidator:Validate(userId: number, data: any): (boolean, { string })
    if not self.RateLimiter:Allow(userId) then
        return false, { "Too many requests" }
    end
    return self.Inner:Validate(userId, data)
end
```

---

### Facade
**Tier:** Already implemented
**Problem:** Simplified interface over a complex subsystem.
**In this codebase:** This is exactly what `[ContextName]Context.lua` is — a Facade over the Application services. The Knit client calls one method; the Context delegates to the right service. You don't need to add Facade explicitly; it's the Context file pattern.

---

### Flyweight
**Tier:** Applicable (performance-specific)
**Problem:** Large numbers of similar objects consuming too much memory. Splits intrinsic (shared, immutable) state from extrinsic (per-instance) state.
**Trigger:** You have thousands of entities (terrain tiles, projectiles, particles) that share most of their data. JECS components are already Flyweight-friendly — store shared config in a config table and per-entity deltas in components.

```lua
-- Intrinsic state (shared, frozen config table)
local ENEMY_CONFIG = table.freeze({
    Goblin = { MaxHP = 50, Speed = 12, Damage = 5 },
    Orc    = { MaxHP = 120, Speed = 7, Damage = 18 },
})

-- Extrinsic state (per-entity, stored in JECS component)
-- world:set(entity, HPComponent, { Current = 50 })
-- Entity looks up intrinsic data via ENEMY_CONFIG[entityType]
```

**Don't use when:** Entity count is in the hundreds or less — premature optimization.

---

### Proxy
**Tier:** Applicable
**Problem:** A surrogate object that controls access to another object.
**Trigger:** You need lazy initialization (don't create an expensive resource until first use), access control (check permissions before delegating), or caching (cache results of expensive calls).
**In this codebase:** An Infrastructure service wrapping a DataStore call with a cache is a caching proxy.

```lua
local CachedDataProxy = {}
CachedDataProxy.__index = CachedDataProxy

function CachedDataProxy.new(dataStore)
    local self = setmetatable({}, CachedDataProxy)
    self.Store = dataStore
    self.Cache = {}
    return self
end

function CachedDataProxy:Get(key: string): any
    if self.Cache[key] ~= nil then
        return self.Cache[key]
    end
    local value = self.Store:Get(key)
    self.Cache[key] = value
    return value
end
```

---

## Behavioral Patterns

### Chain of Responsibility
**Tier:** Applicable
**Problem:** Pass a request along a chain of handlers until one handles it. Decouples sender from receiver.
**Trigger:** You have a sequence of validation or processing steps where any step can reject the request and short-circuit — and the steps may vary at runtime.

```lua
-- Each handler returns (handled: boolean, result: any)
local function _BuildValidationChain(handlers)
    return function(request)
        for _, handler in handlers do
            local handled, result = handler(request)
            if handled then
                return handled, result
            end
        end
        return false, "No handler accepted the request"
    end
end
```

**Note:** In this codebase, a simpler sequential validator (accumulate all errors) is usually preferred over Chain of Responsibility. Use Chain when steps are truly independent and early rejection is the goal, not error accumulation.

---

### Command
**Tier:** Lua idiom
**Problem:** Encapsulate a request as an object to enable queuing, undo/redo, or logging.
**Lua idiom:** In Lua, a Command is just a closure or a table with an `Execute` function. No class hierarchy needed.

```lua
-- Command as a closure
local function makeAttackCommand(attacker, target, damage)
    return function()
        -- execute the attack
    end
end

-- Queue of commands
local commandQueue = {}
table.insert(commandQueue, makeAttackCommand(attacker, target, 10))
```

**Use the full class-based Command** only when you also need `Undo()` — that requires storing state, which a closure doesn't cleanly support.

---

### Interpreter
**Tier:** Avoid (unless building a DSL)
**Problem:** Defines a grammar and an interpreter for it.
**Why avoid:** Overkill for game logic. Only relevant if you're building a scripting language, rule engine, or expression parser inside the game. If that's the case, reach for this pattern.

---

### Iterator
**Tier:** Lua idiom
**Problem:** Sequential traversal of a collection without exposing internals.
**Lua idiom:** Lua's `for k, v in pairs(tbl)` and `ipairs` are iterators. JECS queries (`world:query()`) are iterators. No custom Iterator class needed.

---

### Mediator
**Tier:** Caution
**Problem:** Centralizes communication between objects so they don't reference each other directly.
**Trigger:** Multiple services need to react to the same event and direct coupling between them would create a web of dependencies.
**In this codebase:** A Knit signal on the Context layer can act as a lightweight mediator — services subscribe to it rather than calling each other directly.
**Caution:** Mediator easily becomes a God object. If the mediator has complex logic, split it — the mediator should only route, not decide.

---

### Memento
**Tier:** Applicable (save/undo systems)
**Problem:** Captures and restores an object's state without violating encapsulation.
**Trigger:** You need save points, undo functionality, or rollback on failure.
**In this codebase:** The Infrastructure sync service already owns all state — a Memento here is a snapshot of the atom state before a mutation, stored so it can be restored if the operation fails.

```lua
function SyncService:WithRollback(entityId: string, mutationFn: () -> ())
    local snapshot = self:GetStateReadOnly(entityId)  -- deep clone = memento
    local ok, err = pcall(mutationFn)
    if not ok then
        self:RestoreSnapshot(entityId, snapshot)
        return false, err
    end
    return true, nil
end
```

---

### Observer
**Tier:** Applicable — already in use
**Problem:** One-to-many dependency: when a subject changes, all observers are notified.
**In this codebase:** Charm atoms are the Observer pattern. Charm-sync propagates atom changes to clients. Knit signals on the Context layer are Observers for server-side event broadcasting. You're already using this — don't reimplement it manually.
**Caution:** Unregistered listeners cause memory leaks. Always clean up signal connections in the service's cleanup/destroy method.

---

### State
**Tier:** Applicable
**Problem:** An object changes behavior based on internal state. Replaces large if/else or match chains.
**Trigger:** A service or entity has 3+ distinct states with meaningfully different behavior in each, and the state transitions have rules.

```lua
-- Instead of:
-- if entity.State == "Idle" then ... elseif entity.State == "Attacking" then ...

local IdleState = {}
IdleState.__index = IdleState
function IdleState:OnTick(entity) end
function IdleState:OnAttackTriggered(entity)
    return AttackingState.new()  -- transition
end

local AttackingState = {}
AttackingState.__index = AttackingState
function AttackingState:OnTick(entity)
    -- run attack logic
end
function AttackingState:OnAttackTriggered(entity)
    return self  -- already attacking, no transition
end
```

**In this codebase:** State objects live in the Domain layer (pure logic, no side effects). The Application layer holds the current state and calls transition methods.

---

### Strategy
**Tier:** Lua idiom
**Problem:** Interchangeable algorithms — swap the algorithm at runtime without changing the client.
**Lua idiom:** Just pass a function. A Strategy class in Lua is unnecessary boilerplate.

```lua
-- Strategy as a function parameter
function DamageCalculator:Calculate(baseDamage: number, strategyFn: (number) -> number): number
    return strategyFn(baseDamage)
end

-- Usage
local critStrategy = function(base) return base * 2 end
local normalStrategy = function(base) return base end

calculator:Calculate(10, critStrategy)
```

**Use a full Strategy class** only when the strategy also needs to carry state (e.g., a damage modifier that tracks stacks).

---

### Template Method
**Tier:** Lua idiom
**Problem:** Defines an algorithm skeleton; subclasses fill in specific steps.
**Lua idiom:** In Lua, pass the varying steps as function parameters (higher-order functions) rather than using inheritance. Lua's inheritance model is manual and verbose — composition is cleaner.

```lua
-- Template as higher-order function
local function executeWithValidation(validateFn, executeFn, userId, data)
    local valid, errors = validateFn(data)
    if not valid then
        warn("[Service] userId:", userId, "- Validation failed")
        return false, table.concat(errors, ", ")
    end
    return executeFn(userId, data)
end
```

---

### Visitor
**Tier:** Caution
**Problem:** Adds operations to an object structure without modifying the classes. Useful for traversing Composite trees.
**Trigger:** You have a stable hierarchy (e.g., a skill tree, an item structure) and need to add many different operations over it (serialization, rendering, cost calculation) without touching the hierarchy classes.
**Caution:** Visitor breaks encapsulation and becomes painful when the element hierarchy changes. Only use when the hierarchy is stable and operations vary frequently.

---

## Pattern relationships relevant to this codebase

| Pair | Note |
|------|------|
| **Observer + Mediator** | Charm atoms (Observer) handle reactive state sync. Use Mediator when multiple backend services need to coordinate on the same event without direct coupling. |
| **Command + Memento** | Together implement undo/redo. Command captures what to do; Memento captures state before it was done. |
| **Factory + Builder** | Factory decides *which* object to create; Builder decides *how* to construct a complex one. Use both when you have multiple complex object types. |
| **State + Strategy** | State manages transitions; Strategy swaps algorithms. If a State also needs swappable behavior within it, inject a Strategy into the State. |
| **Composite + Visitor** | Visitor commonly traverses Composite trees. If you build a Composite (skill tree, quest graph), consider whether Visitor is the right way to add operations to it. |
| **Facade + Adapter** | Context files are Facades. If a Facade wraps a third-party library, the inner layer is an Adapter. |

---

## Quick decision guide

```
Need to create objects without coupling to concrete types?  → Factory Method
Need to create families of related objects?                 → Abstract Factory
Object has many optional parts?                             → Builder
Need to wrap an incompatible interface?                     → Adapter
Need dynamic behavior addition without subclassing?         → Decorator
Multiple states with different behavior?                    → State
Need to pass a request through handlers?                    → Chain of Responsibility
Need to snapshot and restore state?                         → Memento
Swappable algorithm?                                        → Strategy (or just a function)
One-to-many event notification?                             → Observer (use Charm/Knit signals)
Many similar objects, memory pressure?                      → Flyweight
Need lazy init or caching?                                  → Proxy
```
