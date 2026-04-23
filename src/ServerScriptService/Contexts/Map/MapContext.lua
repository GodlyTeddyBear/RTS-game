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
	Owns runtime map bootstrap and ECS zone lookups for play sessions.
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

function MapContext:KnitInit()
	MapBaseContext:KnitInit()
end

function MapContext:KnitStart()
	MapBaseContext:KnitStart()
end

function MapContext:PrepareRuntimeMap(): Result.Result<boolean>
	return Catch(function()
		return self._runtimeMapService:CreateOrReplaceRuntimeMap()
	end, "Map:PrepareRuntimeMap")
end

function MapContext:CleanupRuntimeMap(): Result.Result<boolean>
	return Catch(function()
		return self._runtimeMapService:CleanupRuntimeMap()
	end, "Map:CleanupRuntimeMap")
end

function MapContext:GetZoneInstance(zoneName: string): Result.Result<Instance?>
	return Catch(function()
		Ensure(type(zoneName) == "string" and #zoneName > 0, "InvalidZoneName", Errors.INVALID_ZONE_NAME)
		return Ok(self._entityFactory:GetZoneInstance(zoneName))
	end, "Map:GetZoneInstance")
end

function MapContext:GetGoalInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._entityFactory:GetGoalInstance())
	end, "Map:GetGoalInstance")
end

function MapContext:GetSpawnInstance(): Result.Result<BasePart?>
	return Catch(function()
		return Ok(self._entityFactory:GetSpawnInstance())
	end, "Map:GetSpawnInstance")
end

function MapContext:Destroy()
	Catch(function()
		return self._runtimeMapService:CleanupRuntimeMap()
	end, "Map:Destroy")

	local destroyResult = MapBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Map:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return MapContext
