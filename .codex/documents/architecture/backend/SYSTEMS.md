# Systems Reference

## JECS (Entity-Component-System)

Game entities (characters, items, NPCs, etc.) are managed by a JECS world. Services that create or manage entities belong in the **Infrastructure layer** and must respect DDD boundaries - Domain and Application layers do not interact with JECS directly.

---

## ProfileStore (Data Persistence)

Player data is persisted server-side using ProfileStore.

**Runtime ownership:**
- `src/ServerScriptService/Persistence/ProfileInit.server.lua` creates the ProfileStore and boots SessionManager.
- `src/ServerScriptService/Persistence/SessionManager.lua` owns session start/end and emits persistence lifecycle events.
- `src/ServerScriptService/Persistence/ProfileManager.lua` is the active profile repository (`GetData`, `WaitForData`, etc.).
- `src/ServerScriptService/Persistence/PlayerLifecycleManager.lua` tracks context loader readiness and emits `PlayerReady`.
- `src/ReplicatedStorage/Events/GameEvents/Misc/Persistence.lua` defines canonical persistence event names and schemas.

**Session + event flow:**
1. Player joins -> SessionManager starts ProfileStore session (`StartSessionAsync`), calls `AddUserId` and `Reconcile`.
2. SessionManager registers profile in ProfileManager and initializes lifecycle tracking.
3. SessionManager emits `Persistence.ProfileLoaded` through `GameEvents.Bus`.
4. Context loaders hydrate from profile data, then call `PlayerLifecycleManager:NotifyLoaded(player, contextName)`.
5. When all registered loaders are done, PlayerLifecycleManager emits `Persistence.PlayerReady`.
6. Player leaves -> SessionManager emits `Persistence.ProfileSaving` so contexts flush state into `profile.Data`, then calls `EndSession`.

**Key pattern (session start):**
```lua
local profile = profileStore:StartSessionAsync("Player_" .. player.UserId, {
    Cancel = function()
        return player.Parent ~= Players
    end,
})

profile:AddUserId(player.UserId)
profile:Reconcile()

ProfileManager:Register(player, profile)
PlayerLifecycleManager:InitPlayer(player)
GameEvents.Bus:Emit(GameEvents.Events.Persistence.ProfileLoaded, player)
```

- `profile.Data` - the actual player data table
- `profile:Reconcile()` - merges any missing keys from `Template.lua` into existing data
- `ProfileLoaded` - contexts should hydrate runtime state from profile data
- `ProfileSaving` - contexts should write runtime state back into profile data
- `PlayerReady` - contexts can treat player as fully initialized across all registered loaders

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
| Promise | - | Async/await patterns |
| Charm | - | State management (atoms) |
| Charm-sync | - | State replication server -> client |
| ProfileStore | - | Player data persistence |
| Janitor / Trove | - | Resource cleanup |
| Jest / Testez | - | Testing frameworks |
| Selene | - | Lua linting |

---

## Tool Management

- **Aftman** (`aftman.toml`) - auto-installs Rojo
- **Rokit** (`rokit.toml`) - auto-installs Wally and Rojo

Both are optional - install tools manually if preferred.
