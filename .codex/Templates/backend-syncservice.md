# Backend SyncService Template

Use this as the scaffold reference for a backend sync service.

`BaseSyncService:Init()` creates `Syncer`, so the subclass should only set the constructor fields that the base reads.

If the sync service also owns profile-backed persistence, use `BasePersistenceService` for the profile-store path helpers and profile-manager access.

`$ARGUMENTS` format: `<ContextName> <Name>`

If `$ARGUMENTS` is empty, stop and ask for the context name and sync-service name.

---

## Target Shape

```text
src/ServerScriptService/Contexts/<ContextName>/Infrastructure/Persistence/<Name>.lua
```

---

## Game Object Sync Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseGameObjectSyncService)

function <Name>.new()
	return setmetatable(BaseGameObjectSyncService.new("<ContextName>"), <Name>)
end

function <Name>:_GetComponentRegistryName(): string
	return "<ContextName>ComponentRegistry"
end

function <Name>:_GetEntityFactoryName(): string
	return "<ContextName>EntityFactory"
end

function <Name>:_GetInstanceFactoryName(): string?
	return "<ContextName>InstanceFactory"
end

function <Name>:_QueryPollEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryAliveEntities()
end

function <Name>:_GetDirtyTag(): any?
	return self:GetComponentsOrThrow().DirtyTag
end

function <Name>:_ClearDirty(entity: number)
	self:GetWorldOrThrow():remove(entity, self:GetComponentsOrThrow().DirtyTag)
end

function <Name>:_PollEntity(entity: number, model: Model)
	self:GetEntityFactoryOrThrow():UpdatePosition(entity, ModelPlus.GetPivot(model))
end

function <Name>:_SyncEntity(_entity: number, _model: Model)
	-- sync component state to the model here
end

return <Name>
```

---

## Blink Sync Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts["<ContextName>"].Sync.SharedAtoms)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseSyncService)

function <Name>.new()
	local self = setmetatable({}, <Name>)
	self.AtomKey = "<atomKey>"
	self.BlinkEventName = "Sync<ContextName>"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	self.UseRawPayload = true
	self.SyncInterval = 0.1
	return self
end

function <Name>:SetState(state: any)
	self.Atom(function()
		return state
	end)
end

function <Name>:GetState()
	return self.Atom()
end

return <Name>
```

---

## Blink Client Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.<ContextName>.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.<ContextName>SyncClient)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BaseSyncClient)

function <Name>.new()
	local self = BaseSyncClient.new(BlinkClient, "Sync<ContextName>", "<atomKey>", SharedAtoms.CreateClientAtom)
	return setmetatable(self, <Name>)
end

function <Name>:Start()
	BaseSyncClient.Start(self)
end

function <Name>:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return <Name>
```

---

## Persistence Sync Example

Use this shape when the sync service is responsible for profile-backed state instead of or alongside instance syncing.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BasePersistenceService = require(ReplicatedStorage.Utilities.BasePersistenceService)

local <Name> = {}
<Name>.__index = <Name>
setmetatable(<Name>, BasePersistenceService)

function <Name>.new()
	local self = BasePersistenceService.new("<ContextName>", {
		"<ContextName>",
		"State",
	}, {
		ProfileNotLoadedType = "<ContextName>ProfileNotLoaded",
		ProfileNotLoadedMessage = "[<ContextName>:Persistence] Profile not loaded",
	})
	return setmetatable(self, <Name>)
end

function <Name>:Init(registry: any, _name: string)
	BasePersistenceService.Init(self, registry, _name)
end

function <Name>:LoadPlayerState(player: Player)
	return self:LoadPathData(player)
end

function <Name>:SavePlayerState(player: Player, state: any)
	return self:SetPathValue(player, "CurrentState", state)
end

function <Name>:ClearPlayerState(player: Player)
	return self:DeletePathValue(player, "CurrentState")
end

function <Name>:GetProfileData(player: Player)
	return BasePersistenceService.GetProfileData(self, player)
end

return <Name>
```
