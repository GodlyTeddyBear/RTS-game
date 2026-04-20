# Knit Service Framework

Knit provides service-oriented architecture with auto-discovery, lifecycle management, and remote function/signal setup.

## Auto-Discovery

Knit automatically discovers and loads services/controllers from the Contexts folder. No manual registration needed.

**Server** (`src/ServerScriptService/Runtime.server.lua`):
```lua
local Contexts: Folder = script.Parent.Contexts

for _, context in ipairs(Contexts:GetChildren()) do
    if context:FindFirstChildOfClass("ModuleScript") then
        Knit.AddServices(context)
    end
end

Knit.Start()
```

**Client** (`src/StarterPlayerScripts/ClientRuntime.client.lua`):
```lua
local Contexts = script.Parent:WaitForChild("Contexts")

for _, context in ipairs(Contexts:GetChildren()) do
    if context:FindFirstChildOfClass("ModuleScript") then
        Knit.AddControllers(context)
    end
end

Knit.Start()
```

---

## Service Lifecycle

Services have two lifecycle hooks called by Knit automatically:

- `KnitInit()` — called before any service's `KnitStart`. Use for internal setup (state initialization, binding events). Cannot safely call other services here.
- `KnitStart()` — called after all services have initialized. Safe to call other services via `Knit.GetService()`.

```lua
local UserService = {}
UserService.__index = UserService

function UserService.new(validator, storage, syncService)
    local self = setmetatable({}, UserService)
    self.Validator = validator
    self.Storage = storage
    self.SyncService = syncService
    return self
end

function UserService:KnitInit()
    -- Internal setup — do not call other services here
end

function UserService:KnitStart()
    -- Safe to access other services
end

function UserService:LoadUser(userId: number): (boolean, TUserData | string)
    return true, userData
end

return UserService
```

---

## Client Remotes

Expose methods and signals to the client via the `.Client` table on a service. Knit wraps these automatically as RemoteFunctions and RemoteEvents.

```lua
MyService.Client = {}

-- RemoteFunction (client calls, server returns value)
function MyService.Client:GetData(player, userId)
    return self.Server:LoadUser(userId)
end

-- RemoteEvent (fire-and-forget)
MyService.Client.OnDataChanged = Knit.CreateSignal()
```

---

## Creating a New Service

1. Create the service file in the appropriate layer directory
2. Implement `.new(dependencies)` constructor with injected dependencies
3. Implement `KnitInit()` and/or `KnitStart()` as needed
4. Knit auto-discovers and loads it — no registration step

The service will be auto-discovered as long as it lives under a `Contexts/` subfolder that Knit scans.
