--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)

local Errors = require(script.Parent.Errors)
local MapECSWorldService = require(script.Parent.Infrastructure.ECS.MapECSWorldService)
local MapComponentRegistry = require(script.Parent.Infrastructure.ECS.MapComponentRegistry)
local MapEntityFactory = require(script.Parent.Infrastructure.ECS.MapEntityFactory)
local RuntimeMapService = require(script.Parent.Infrastructure.Services.RuntimeMapService)

local Catch = Result.Catch
local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class MapContext
	Owns runtime map bootstrap and ECS zone lookups for play sessions.
	@server
]=]
local MapContext = Knit.CreateService({
	Name = "MapContext",
	Client = {},
})

local function _InitModule(registry: any, moduleName: string)
	local module = registry:Get(moduleName)
	if type(module) == "function" then
		return
	end

	if module and module.Init and type(module.Init) == "function" then
		module:Init(registry, moduleName)
	end
end

function MapContext:KnitInit()
	local registry = Registry.new("Server")
	local worldService = MapECSWorldService.new()
	local world = worldService:GetWorld()

	registry:Register("MapECSWorldService", worldService, "Infrastructure")
	registry:Register("World", world)
	registry:Register("MapComponentRegistry", MapComponentRegistry.new(), "Infrastructure")
	registry:Register("MapEntityFactory", MapEntityFactory.new(), "Infrastructure")
	registry:Register("RuntimeMapService", RuntimeMapService.new(), "Infrastructure")

	-- Initialize ECS core modules in deterministic order so component ids exist before factories use them.
	_InitModule(registry, "MapECSWorldService")
	_InitModule(registry, "MapComponentRegistry")
	_InitModule(registry, "MapEntityFactory")
	_InitModule(registry, "RuntimeMapService")

	self._registry = registry
	self._world = world
	self._components = registry:Get("MapComponentRegistry"):GetComponents()
	self._entityFactory = registry:Get("MapEntityFactory")
	self._runtimeMapService = registry:Get("RuntimeMapService")
end

function MapContext:KnitStart()
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

function MapContext:Destroy()
	Catch(function()
		return self._runtimeMapService:CleanupRuntimeMap()
	end, "Map:Destroy")
end

WrapContext(MapContext, "Map")

return MapContext
