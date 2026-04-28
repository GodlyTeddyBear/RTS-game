# Systems Reference

## JECS (Entity-Component-System)

Game entities (characters, items, NPCs, etc.) are managed by a JECS world. Services that create or manage entities belong in the **Infrastructure layer** and must respect DDD boundaries - Domain and Application layers do not interact with JECS directly.

For the ECS role split and ownership boundaries, see [ECS_OVERVIEW.md](ECS_OVERVIEW.md).

---

## ProfileStore (Data Persistence)

Player data is persisted server-side using ProfileStore.

ECS-to-ProfileStore bridging is documented in [ECS_PERSISTENCE_RULES.md](../../methods/ECS/ECS_PERSISTENCE_RULES.md).

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

## Shared Utilities

Common backend and ECS utilities live in `ReplicatedStorage/Utilities/` and are described in [UTILITY_USE.md](UTILITY_USE.md).

Base-class style utilities are a valid pattern here when they provide shared technical behavior without owning a context lifecycle. For example, `BaseAction` is a reusable action base class that centralizes marker dispatch, null checking, and callback routing while leaving subclass-specific logic in the derived class.

Use this pattern when the utility:
- exposes a small shared API surface
- owns reusable technical behavior
- lets subclasses override narrow hooks
- does not become a feature service or lifecycle owner

---

## Tool Management

- **Aftman** (`aftman.toml`) - auto-installs Rojo
- **Rokit** (`rokit.toml`) - auto-installs Wally and Rojo

Both are optional - install tools manually if preferred.
