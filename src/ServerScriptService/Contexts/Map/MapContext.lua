--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Errors)
local MapEntityReadService = require(script.Parent.Infrastructure.Entity.MapEntityReadService)
local MapEntitySchema = require(script.Parent.Infrastructure.Entity.MapEntitySchema)
local AuthoredMapLookupService = require(script.Parent.Infrastructure.Services.AuthoredMapLookupService)
local RuntimeMapService = require(script.Parent.Infrastructure.Services.RuntimeMapService)

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "MapEntityReadService",
		Factory = function(service: any, _baseContext: any)
			return MapEntityReadService.new()
		end,
		CacheAs = "_mapEntityReadService",
	},
	{
		Name = "RuntimeMapService",
		Factory = function(service: any, _baseContext: any)
			return RuntimeMapService.new()
		end,
		CacheAs = "_runtimeMapService",
	},
	{
		Name = "AuthoredMapLookupService",
		Module = AuthoredMapLookupService,
		CacheAs = "_authoredMapLookupService",
	},
}

local MapModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

--[=[
	@class MapContext
	Knit service that owns runtime map bootstrap, teardown, and ECS lookup access for the Map context.
	`KnitInit()` and `KnitStart()` delegate shared context lifecycle into `BaseContext`.
	`PrepareRuntimeMap()` and `CleanupRuntimeMap()` proxy the runtime map service.
	`GetZoneInstance()`, `GetSpawnInstance()`, `GetBaseInstance()`, and `GetBaseAnchor()` expose the active map's discovered instances.
	`GetLobbyInstance()`, `GetLobbySpawnInstance()`, `GetLobbySpawnCFrame()`, and `GetRunEntryCFrame()` expose authored session-space markers.
	@server
]=]
local MapContext = Knit.CreateService({
	Name = "MapContext",
	Client = {},
	Modules = MapModules,
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
	},
})

local MapBaseContext = BaseContext.new(MapContext)

-- ── Initialization ─────────────────────────────────────────────────────────────

--[=[
	@within MapContext
	Resets the wrapped BaseContext so map lifecycle state starts from a clean slate.
]=]
function MapContext:KnitInit()
	MapBaseContext:KnitInit()
end

--[=[
	@within MapContext
	Starts the wrapped BaseContext after its shared dependencies are ready.
]=]
function MapContext:KnitStart()
	MapBaseContext:KnitStart()
	self._mapEntityReadService:Configure(self._entityContext)
	self._runtimeMapService:Configure(self._entityContext, self._mapEntityReadService)
	local registrationResult = self:_RegisterEntityInfrastructure()
	if not registrationResult.success then
		error(("MapContext failed to register Entity infrastructure: [%s] %s"):format(
			tostring(registrationResult.type),
			tostring(registrationResult.message)
		))
	end
end

function MapContext:_RegisterEntityInfrastructure(): Result.Result<boolean>
	return Catch(function()
		return self._entityContext:RegisterEntityFeature({
			World = "Location",
			FeatureName = "Map",
			Schema = MapEntitySchema,
		})
	end, "Map:RegisterEntityInfrastructure")
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	@within MapContext
	Creates or replaces the runtime map model through the map runtime service.
	@return Result.Result<boolean> -- Whether the runtime map was created successfully.
]=]
function MapContext:PrepareRuntimeMap(): Result.Result<boolean>
	return Catch(function()
		return self._runtimeMapService:CreateOrReplaceRuntimeMap()
	end, "Map:PrepareRuntimeMap")
end

--[=[
	@within MapContext
	Removes the active runtime map model through the map runtime service.
	@return Result.Result<boolean> -- Whether the runtime map cleanup succeeded.
]=]
function MapContext:CleanupRuntimeMap(): Result.Result<boolean>
	return Catch(function()
		return self._runtimeMapService:CleanupRuntimeMap()
	end, "Map:CleanupRuntimeMap")
end

--[=[
	@within MapContext
	Resolves a zone instance from the active runtime map after validating the name.
	@param zoneName string -- The zone name to resolve.
	@return Result.Result<Instance?> -- The resolved zone instance, if present.
]=]
function MapContext:GetZoneInstance(zoneName: string): Result.Result<Instance?>
	return Catch(function()
		Ensure(type(zoneName) == "string" and #zoneName > 0, "InvalidZoneName", Errors.INVALID_ZONE_NAME)
		return Ok(self._mapEntityReadService:GetZoneInstance(zoneName))
	end, "Map:GetZoneInstance")
end

--[=[
	@within MapContext
	Returns the spawn marker instance from the active runtime map, if one exists.
	@return Result.Result<BasePart?> -- The active spawn instance, if present.
]=]
function MapContext:GetSpawnInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._mapEntityReadService:GetSpawnInstance())
	end, "Map:GetSpawnInstance")
end

--[=[
	@within MapContext
	Returns the base instance from the active runtime map, if one exists.
	@return Result.Result<Instance?> -- The active base instance, if present.
]=]
function MapContext:GetBaseInstance(): Result.Result<Instance?>
	return Catch(function()
		return Ok(self._mapEntityReadService:GetBaseInstance())
	end, "Map:GetBaseInstance")
end

--[=[
	@within MapContext
	Returns the base anchor from the active runtime map, if one exists.
	@return Result.Result<BasePart?> -- The active base anchor, if present.
]=]
function MapContext:GetBaseAnchor(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._mapEntityReadService:GetBaseAnchor())
	end, "Map:GetBaseAnchor")
end

--[=[
	@within MapContext
	Returns the active runtime map model, if one exists.
	@return Result.Result<Model?> -- The active runtime map model, if present.
]=]
function MapContext:GetRuntimeMapInstance(): Result.Result<Model?>
	return Catch(function()
		return Ok(self._mapEntityReadService:GetRuntimeMapInstance())
	end, "Map:GetRuntimeMapInstance")
end

--[=[
	@within MapContext
	Returns the authored lobby model, if one exists under `Workspace.Map.Lobby`.
	@return Result.Result<Model?> -- The authored lobby model, if present.
]=]
function MapContext:GetLobbyInstance(): Result.Result<Model?>
	return Catch(function()
		return Ok(self._authoredMapLookupService:GetLobbyInstance())
	end, "Map:GetLobbyInstance")
end

--[=[
	@within MapContext
	Returns the authored lobby spawn anchor, if one exists.
	@return Result.Result<BasePart?> -- The authored lobby spawn anchor, if present.
]=]
function MapContext:GetLobbySpawnInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._authoredMapLookupService:GetLobbySpawnInstance())
	end, "Map:GetLobbySpawnInstance")
end

--[=[
	@within MapContext
	Returns the authored lobby spawn CFrame.
	@return Result.Result<CFrame> -- The authored lobby spawn CFrame.
]=]
function MapContext:GetLobbySpawnCFrame(): Result.Result<CFrame>
	return Catch(function()
		return self._authoredMapLookupService:GetLobbySpawnCFrame()
	end, "Map:GetLobbySpawnCFrame")
end

--[=[
	@within MapContext
	Returns the authored run-entry anchor, if one exists.
	@return Result.Result<BasePart?> -- The authored run-entry anchor, if present.
]=]
function MapContext:GetRunEntryInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._authoredMapLookupService:GetRunEntryInstance())
	end, "Map:GetRunEntryInstance")
end

--[=[
	@within MapContext
	Returns the authored run-entry CFrame.
	@return Result.Result<CFrame> -- The authored run-entry CFrame.
]=]
function MapContext:GetRunEntryCFrame(): Result.Result<CFrame>
	return Catch(function()
		return self._authoredMapLookupService:GetRunEntryCFrame()
	end, "Map:GetRunEntryCFrame")
end

--[=[
	@within MapContext
	Cleans up runtime map state before tearing down the wrapped BaseContext.
]=]
function MapContext:Destroy()
	-- Clean up the runtime map first so the wrapped BaseContext can tear down shared services safely.
	Catch(function()
		return self._runtimeMapService:CleanupRuntimeMap()
	end, "Map:Destroy")

	-- Tear down the shared BaseContext wrapper and convert any failure into a mentionable error.
	local destroyResult = MapBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Map:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return MapContext
