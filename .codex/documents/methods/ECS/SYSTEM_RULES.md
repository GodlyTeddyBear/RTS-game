# System Rules


---
## Core Rules

- Systems are stateless — all state lives in components, not in the system object
- Systems declare their reads and writes explicitly at the top of every `Tick` method
- Exactly one system owns writes to any given `[AUTHORITATIVE]` component
- Systems never call other systems directly — communicate through components or events
- Systems do not hardcode entity IDs — they query via factory methods
- Systems belong to exactly one phase
- Deferred operations (spawn, destroy) are queued and flushed at phase boundaries, never mid-tick


---
## Statelessness

A system may hold references to its dependencies (factory, event bus, config) but never mutable state. If you find yourself storing frame-to-frame values on the system, those values belong in a component.

```lua
-- CORRECT: system holds only injected dependencies
function StructureAttackSystem.new(factory: StructureEntityFactory, eventBus: EventBus)
    return setmetatable({ _factory = factory, _eventBus = eventBus }, StructureAttackSystem)
end

-- WRONG: system holds mutable state
self._lastAttackTime = tick() -- this belongs in a component
```


---
## Read/Write Declaration

Every `Tick` method declares its reads and writes in comments at the top. This is the contract between the system and the phase scheduler.

```lua
-- READS: AttackStatsComponent [AUTHORITATIVE], CooldownComponent [AUTHORITATIVE], TargetComponent [AUTHORITATIVE]
-- WRITES: CooldownComponent [AUTHORITATIVE]
function StructureAttackSystem:Tick(dt: number)
    for _, entity in ipairs(self._factory:QueryActiveEntities()) do
        local stats = self._factory:GetAttackStats(entity)
        local cooldown = self._factory:GetCooldown(entity)

        local elapsed = cooldown.Elapsed + dt
        self._factory:SetCooldownElapsed(entity, elapsed)

        if elapsed >= stats.AttackCooldown then
            self._eventBus:Fire("AttackReady", { entity = entity })
        end
    end
end
```


---
## Communication

Systems communicate intent through events or by writing components — never by calling another system's methods.

```lua
-- CORRECT: fire an event; another system handles it
self._eventBus:Fire("AttackReady", { entity = entity })

-- WRONG: direct cross-system call
self._damageSystem:ApplyDamage(entity, damage)
```


---
## Ownership

No two systems write the same `[AUTHORITATIVE]` component. If a second system needs to influence a value, it does so by writing a separate input component that the owning system reads.

```lua
-- CORRECT: DamageInputSystem writes DamageInputComponent [AUTHORITATIVE]
--          HealthSystem reads DamageInputComponent and writes Health [AUTHORITATIVE]

-- WRONG: both AttackSystem and PoisonSystem write Health directly
```

---

## Examples

<!-- Add context-specific correct usage examples here when updating this contract. -->

---

## Prohibitions

- Do not violate the required rules defined in this document's Core Rules and contract sections.

---

## Failure Signals

- Implementation behavior contradicts one or more required rules in this contract.

---

## Checklist

- [ ] All required rules in this contract are satisfied.

