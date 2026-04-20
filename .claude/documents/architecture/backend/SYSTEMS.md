# Systems Reference

## JECS (Entity-Component-System)

Game entities (characters, items, NPCs, etc.) are managed by a JECS world. Services that create or manage entities belong in the **Infrastructure layer** and must respect DDD boundaries — Domain and Application layers do not interact with JECS directly.

---

## ProfileStore (Data Persistence)

Player data is persisted server-side using ProfileStore.

**Flow:**
1. Player joins → `DataInit.server.lua` starts a ProfileStore session
2. Profile stored at `DataManager.Profiles[player]`
3. Player leaves → session ends and profile is cleaned up

**Key pattern:**
```lua
local profile = PStore:StartSessionAsync("Player_" .. player.UserId, {
    Cancel = function()
        return player.Parent ~= Players  -- Cancel if player already left
    end,
})

profile:AddUserId(player.UserId)
profile:Reconcile()  -- Fill missing fields from data template

DManager.Profiles[player] = profile
```

- `profile.Data` — the actual player data table
- `profile:Reconcile()` — merges any missing keys from `Template.lua` into existing data

---

## Debug Logging

Debug logging is toggled via config without affecting functionality.

**Master switch** (`ReplicatedStorage/Config/DebugConfig.lua`):
```lua
return table.freeze({
    ENABLED = false,  -- Set true to enable all debug logs
})
```

**Context-specific config** (`[Context]/Config/DebugConfig.lua`):
```lua
return table.freeze({
    CONTEXT_ENABLED = true,
    SERVICE_NAME = true,
    MILESTONE = true,
})
```

**Usage:**
```lua
local DebugLogger = require(script.Parent.Parent.Config.DebugLogger)

function Service.new(validator)
    local self = setmetatable({}, Service)
    self.Validator = validator
    self.DebugLogger = DebugLogger.new()
    return self
end

function Service:Execute(userId: number)
    local success, errors = self.Validator:Validate(userId)
    self.DebugLogger:Log("Service", "Validation", "userId: " .. userId .. " result: " .. tostring(success))
    return true, result
end
```

---

## Key Libraries

| Library | Version | Purpose |
|---|---|---|
| Knit | 1.7.0 | Service-oriented architecture |
| JECS | 0.9.0 | Entity-Component-System |
| Promise | — | Async/await patterns |
| Charm | — | State management (atoms) |
| Charm-sync | — | State replication server → client |
| ProfileStore | — | Player data persistence |
| Janitor / Trove | — | Resource cleanup |
| Jest / Testez | — | Testing frameworks |
| Selene | — | Lua linting |

---

## Tool Management

- **Aftman** (`aftman.toml`) — auto-installs Rojo
- **Rokit** (`rokit.toml`) — auto-installs Wally and Rojo

Both are optional — install tools manually if preferred.
