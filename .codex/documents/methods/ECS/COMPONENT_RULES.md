# Component Rules


---
## Core Rules

- Components are pure data — no methods, no logic, no behavior
- One responsibility per component — do not bundle unrelated fields
- Components never reference other components directly — only entity IDs
- All component fields must be valid at any point in time — no partial initialization states
- Tags (zero-field components) are first-class citizens; prefer them over boolean fields


---
## Authority Labels

Every component carries one of two authority labels. The label must appear in the component registry comment.

### `[AUTHORITATIVE]`
This component is the source of truth. Exactly one system owns writes to it. All other systems treat it as read-only.

### `[DERIVED]`
This component reflects the value of one or more `[AUTHORITATIVE]` components. It is never written directly by external systems. One dedicated sync system is responsible for keeping it current. It exists for performance or convenience only — it carries no semantic weight of its own.

**Rules for `[DERIVED]` components:**
- Never write a `[DERIVED]` component from outside its designated sync system
- If a `[DERIVED]` value disagrees with its source, the source wins — the derived value is stale
- `[DERIVED]` components are always updated in the Sync phase, after all `[AUTHORITATIVE]` writes are complete
- A component cannot be both `[AUTHORITATIVE]` and `[DERIVED]` — split it if tempted


---
## Component Registries

- Registries are always frozen after initialization with `table.freeze`
- Every component is named with `_nameComponent` for debuggability
- Raw component IDs are never exposed outside the registry and its factory


---
## Examples
```lua
function EnemyComponentRegistry:Init(registry: any, _name: string)
    local world = registry:Get("World")

    -- [AUTHORITATIVE] source of truth for enemy health
    local health = world:component() -- { current: number, max: number }
    _nameComponent(world, health, "Enemy.Health")

    -- [DERIVED] reflects Health — only HealthSyncSystem writes this
    local healthPercent = world:component() -- { value: number }
    _nameComponent(world, healthPercent, "Enemy.HealthPercent")

    -- Tag: zero-field state marker
    local aliveTag = world:entity()
    _nameComponent(world, aliveTag, "Enemy.AliveTag")

    self._components = table.freeze({
        Health = health,           -- [AUTHORITATIVE]
        HealthPercent = healthPercent, -- [DERIVED]
        AliveTag = aliveTag,
    })
end
```

---

## Prohibitions

- Do not violate the required rules defined in this document's Core Rules and contract sections.

---

## Failure Signals

- Implementation behavior contradicts one or more required rules in this contract.

---

## Checklist

- [ ] All required rules in this contract are satisfied.

