# Phase and Execution Rules

## Core Rules

- Phase order is declared in one place per context and is the single source of truth
- Every system belongs to exactly one phase
- No system depends on ordering relative to another system within the same phase — if order matters, use separate phases
- Deferred operations (entity creation, destruction) flush at the end of the Logic phase, before Sync
- `[DERIVED]` components are updated in the Sync phase, after all `[AUTHORITATIVE]` writes are complete
- Systems in the Render phase are read-only — no component writes

## Standard Phase Order

```
Input  →  Logic  →  Sync  →  Render
```

| Phase | Purpose | Writes Allowed |
|-------|---------|----------------|
| Input | Read player or AI intent into components | `[AUTHORITATIVE]` input components |
| Logic | Systems mutate authoritative components; deferred ops flush at end | `[AUTHORITATIVE]` components |
| Sync | Derived components updated to reflect authoritative values; deferred ops have already flushed | `[DERIVED]` components only |
| Render | Push values to UI or visuals | None |

## Phase Declaration

Phase order is declared once per context, typically in the world service. Never rely on implicit ordering.

```lua
-- Single source of truth for phase order in this context
local PHASES = {
    "Input",  -- 1
    "Logic",  -- 2
    "Sync",   -- 3
    "Render", -- 4
}
```

## Deferred Operation Flush

Entity creation and destruction queued during the Logic phase are flushed at the end of Logic, before Sync runs. This ensures the Sync phase sees a stable, fully updated set of entities.

```lua
-- World service tick loop
function EnemyECSWorldService:Tick(dt: number)
    self._inputSystem:Tick(dt)       -- Input phase

    self._attackSystem:Tick(dt)      -- Logic phase
    self._movementSystem:Tick(dt)    -- Logic phase
    self._factory:FlushDestructionQueue() -- end of Logic: flush deferred ops

    self._healthSyncSystem:Tick()    -- Sync phase

    -- Render phase: UI systems read components, write nothing
end
```

## Sync Phase Example

`[DERIVED]` components are updated in Sync after all `[AUTHORITATIVE]` writes in Logic are complete.

```lua
-- READS: Health [AUTHORITATIVE]
-- WRITES: HealthPercent [DERIVED]
function HealthSyncSystem:Tick()
    for _, entity in ipairs(self._factory:QueryAliveEntities()) do
        local health = self._factory:GetHealth(entity)
        self._factory:SetHealthPercent(entity, health.current / health.max)
    end
end
```
