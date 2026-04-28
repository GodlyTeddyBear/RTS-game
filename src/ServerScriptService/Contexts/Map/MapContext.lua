--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Errors)
local MapECSWorldService = require(script.Parent.Infrastructure.ECS.MapECSWorldService)
local MapComponentRegistry = require(script.Parent.Infrastructure.ECS.MapComponentRegistry)
local MapEntityFactory = require(script.Parent.Infrastructure.ECS.MapEntityFactory)
local RuntimeMapService = require(script.Parent.Infrastructure.Services.RuntimeMapService)

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "MapComponentRegistry",
		Module = MapComponentRegistry,
	},
	{
		Name = "MapEntityFactory",
		Module = MapEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "RuntimeMapService",
		Module = RuntimeMapService,
		CacheAs = "_runtimeMapService",
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
	@server
]=]
local MapContext = Knit.CreateService({
	Name = "MapContext",
	Client = {},
	WorldService = {
		Name = "MapECSWorldService",
		Module = MapECSWorldService,
	},
	Modules = MapModules,
	Cache = {
		World = "_world",
		MapComponents = {
			Field = "_components",
			From = "MapComponentRegistry",
			Method = "GetComponents",
			Result = false,
		},
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
		return Ok(self._entityFactory:GetZoneInstance(zoneName))
	end, "Map:GetZoneInstance")
end

--[=[
	@within MapContext
	Returns the spawn marker instance from the active runtime map, if one exists.
	@return Result.Result<BasePart?> -- The active spawn instance, if present.
]=]
function MapContext:GetSpawnInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._entityFactory:GetSpawnInstance())
	end, "Map:GetSpawnInstance")
end

--[=[
	@within MapContext
	Returns the base instance from the active runtime map, if one exists.
	@return Result.Result<Instance?> -- The active base instance, if present.
]=]
function MapContext:GetBaseInstance(): Result.Result<Instance?>
	return Catch(function()
		return Ok(self._entityFactory:GetBaseInstance())
	end, "Map:GetBaseInstance")
end

--[=[
	@within MapContext
	Returns the base anchor from the active runtime map, if one exists.
	@return Result.Result<BasePart?> -- The active base anchor, if present.
]=]
function MapContext:GetBaseAnchor(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._entityFactory:GetBaseAnchor())
	end, "Map:GetBaseAnchor")
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
