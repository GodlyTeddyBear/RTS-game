# Backend Context Template

Use this as the bare scaffold reference for a new backend bounded context named `$ARGUMENTS`.

If `$ARGUMENTS` is empty, stop and ask for the context name.

---

## Target Shape

```text
src/ServerScriptService/Contexts/<ContextName>/
|-- <ContextName>Context.lua
|-- Errors.lua
|-- Application/
|   |-- Commands/
|   `-- Queries/
|-- <ContextName>Domain/
|   |-- Policies/
|   `-- Specs/
`-- Infrastructure/
    |-- ECS/
    |-- Persistence/
    `-- Services/

src/ReplicatedStorage/Contexts/<ContextName>/
`-- Types/
    `-- <ContextName>Types.lua
```

---

## Context Entry Example

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local <ContextName>ComponentRegistry = require(script.Parent.Infrastructure.ECS["<ContextName>ComponentRegistry"])
local <ContextName>EntityFactory = require(script.Parent.Infrastructure.ECS["<ContextName>EntityFactory"])
local <ContextName>WorldService = require(script.Parent.Infrastructure.ECS["<ContextName>WorldService"])
local <ContextName>SyncService = require(script.Parent.Infrastructure.Persistence["<ContextName>SyncService"])
local <ContextName>Policy = require(script.Parent["<ContextName>Domain"].Policies["<ContextName>Policy"])
local <ContextName>Spec = require(script.Parent["<ContextName>Domain"].Specs["<ContextName>Spec"])
local DoThingCommand = require(script.Parent.Application.Commands.DoThingCommand)
local GetThingQuery = require(script.Parent.Application.Queries.GetThingQuery)

local Ok = Result.Ok

local <ContextName> = Knit.CreateService({
	Name = "<ContextName>Context",
	Client = {},
	Modules = {
		Infrastructure = {
			{
				Name = "<ContextName>WorldService",
				Module = <ContextName>WorldService,
			},
			{
				Name = "<ContextName>ComponentRegistry",
				Module = <ContextName>ComponentRegistry,
			},
			{
				Name = "<ContextName>EntityFactory",
				Module = <ContextName>EntityFactory,
				CacheAs = "_entityFactory",
			},
			{
				Name = "<ContextName>SyncService",
				Module = <ContextName>SyncService,
				CacheAs = "_syncService",
			},
		},
		Domain = {
			{
				Name = "<ContextName>Policy",
				Module = <ContextName>Policy,
			},
			{
				Name = "<ContextName>Spec",
				Module = <ContextName>Spec,
			},
		},
		Application = {
			{
				Name = "DoThingCommand",
				Module = DoThingCommand,
				CacheAs = "_doThingCommand",
			},
			{
				Name = "GetThingQuery",
				Module = GetThingQuery,
				CacheAs = "_getThingQuery",
			},
		},
	},
	ProfileLifecycle = {
		LoaderName = "<ContextName>",
		OnLoaded = "HandleProfileLoaded",
		OnSaving = "HandleProfileSaving",
		OnRemoving = "HandleProfileRemoving",
	},
})

local <ContextName>BaseContext = BaseContext.new(<ContextName>)

function <ContextName>:KnitInit()
	<ContextName>BaseContext:KnitInit()
	<ContextName>BaseContext:RegisterProfileLoader()
	<ContextName>BaseContext:StartProfileLifecycle()
	<ContextName>BaseContext:RegisterSyncSystem("_syncService", nil, "Stepped")
	<ContextName>BaseContext:RegisterSchedulerSystem("Heartbeat", function()
		-- custom server work here
	end)
	<ContextName>BaseContext:OnGameEvent(GameEvents.Events.Run.WaveStarted, function(waveNumber: number, isEndless: boolean)
		self:HandleWaveStarted(waveNumber, isEndless)
	end, "_waveStartedConnection")
	<ContextName>BaseContext:OnContextEvent("<ContextName>", "Updated", "HandleContextUpdated", "_contextUpdatedConnection")
end

function <ContextName>:KnitStart()
	<ContextName>BaseContext:KnitStart()
	<ContextName>BaseContext:HydrateExistingAndAddedPlayers("_syncService")
	<ContextName>BaseContext:RemoveLeavingPlayersByUserId("_syncService")
end

function <ContextName>:GetStatus(): Result.Result<string>
	return Ok("Ready")
end

function <ContextName>.Client:RequestStatus(_player: Player): string
	local result = self.Server:GetStatus()
	if result.success then
		return result.value
	end

	return "Unknown"
end

function <ContextName>:HandleProfileLoaded(_player: Player)
	-- hydrate runtime state from profile data here
end

function <ContextName>:HandleProfileSaving(_player: Player)
	-- write runtime state into profile data here
end

function <ContextName>:HandleProfileRemoving(_player: Player)
	-- release profile-scoped resources here
end

function <ContextName>:HandleWaveStarted(_waveNumber: number, _isEndless: boolean)
	-- react to a shared game event here
end

function <ContextName>:HandleContextUpdated(_value: string)
	-- react to a context-scoped event here
end

function <ContextName>:PublishUpdated(value: string)
	<ContextName>BaseContext:EmitGameEvent(GameEvents.Events.<ContextName>.Updated, value)
	<ContextName>BaseContext:EmitContextEvent("<ContextName>", "Updated", value)
end

function <ContextName>:ReadSchedulerDelta(): number
	return <ContextName>BaseContext:GetSchedulerDeltaTime()
end

return <ContextName>
```

---

## Example Calls

```lua
-- Server-side call
local statusResult = <ContextName>:GetStatus()

-- Client-side call
local status = <ContextName>:RequestStatus()

-- Event call
<ContextName>:PublishUpdated("ready")

-- Scheduler/data call
local deltaTime = <ContextName>:ReadSchedulerDelta()
```

---

## Base Context Methods

```lua
<ContextName>BaseContext:OnProfileLoaded("HandleProfileLoaded", "_profileLoadedConnection")
<ContextName>BaseContext:OnProfileSaving("HandleProfileSaving", "_profileSavingConnection")
<ContextName>BaseContext:OnProfileRemoving("HandleProfileRemoving", "_profileRemovingConnection")
<ContextName>BaseContext:OnGameEvent(GameEvents.Events.Run.WaveStarted, function() end)
<ContextName>BaseContext:OnContextEvent("<ContextName>", "Updated", "HandleContextUpdated")
<ContextName>BaseContext:RegisterSyncSystem("_syncService", nil, "Stepped")
<ContextName>BaseContext:RegisterPollSystem("_entityFactory", "PollThing", "Heartbeat")
<ContextName>BaseContext:RegisterSchedulerSystem("Heartbeat", function() end)
<ContextName>BaseContext:HydrateExistingAndAddedPlayers("_syncService")
<ContextName>BaseContext:RemoveLeavingPlayersByUserId("_syncService")
```

---

## Errors

```lua
--!strict

local Errors = table.freeze({
	-- Key = "Context:Message",
})

return Errors
```

---

## Shared Types

```lua
--!strict

--[=[
	@class <ContextName>Types
	Defines shared <context> shapes.
	@server
	@client
]=]
local <ContextName>Types = {}

export type Example = {
	-- shared context types go here
}

return table.freeze(<ContextName>Types)
```
