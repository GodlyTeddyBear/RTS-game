# Frontend Layers

Every feature slice has three internal layers. Dependencies only flow downward — a layer may never import from the layer above it.

```
Presentation Layer
      ↓
Application Layer
      ↓
Infrastructure Layer
      ↓
ReplicatedStorage (shared packages, types, config)
```

---

## Infrastructure Layer

**Responsibility**: State management and backend communication.

**Lives in**: `[Feature]/Infrastructure/`

**Contains:**
- `[Name]Atom.lua` — creates and exports a Charm atom
- `[Name]SyncClient.lua` — initializes Charm-sync client to receive server state
- Service clients wrapping Knit remote calls

**Atom example:**
```lua
-- Counter/Infrastructure/CounterAtom.lua
local Charm = require(ReplicatedStorage.Packages.Charm)

export type TCounterState = {
    Count: number,
    TotalClicks: number,
    LastUpdated: number,
}

local function createCounterAtom()
    return Charm.atom({
        Count = 0,
        TotalClicks = 0,
        LastUpdated = os.time(),
    } :: TCounterState)
end

return createCounterAtom
```

**Sync client example:**
```lua
-- [Feature]/Infrastructure/[Feature]SyncClient.lua
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])

function SyncClient:Start(BlinkClient)
    local syncer = CharmSync.client({
        atoms = { entityData = self.EntityAtom },
    })

    BlinkClient.Sync.On(function(payload)
        syncer:sync(payload)
    end)
end
```

---

## Application Layer

**Responsibility**: Orchestration, state access, business logic, data transformation.

**Lives in**: `[Feature]/Application/`

**Contains:**
- `Hooks/` — read hooks and write hooks (always separate files)
- `ViewModels/` — transform raw atom data into UI-ready frozen tables

See [HOOKS.md](HOOKS.md) for detailed hook patterns and ViewModel rules.

---

## Presentation Layer

**Responsibility**: Pure rendering and user interaction. No business logic.

**Lives in**: `[Feature]/Presentation/`

**Contains:**
- `Organisms/` — feature-specific complex components
- `Templates/` — full screens / major layouts (always feature-local)
- `init.lua` — feature root export (public Presentation API)

Components receive data via props (from ViewModels) and actions via props (from write hooks). They never call services or mutate atoms directly.

`Presentation/init.lua` rules:
- External consumers (for example `App`) should import a feature's Presentation API via `require(...[Feature].Presentation.init)`.
- `init.lua` exports only mountable Presentation surfaces (screens/overlays), not Application hooks or Infrastructure modules.
- Avoid deep external imports to `Presentation/Templates/*` unless performing local, same-feature composition.

See [COMPONENTS.md](COMPONENTS.md) for the Atomic Design hierarchy.
