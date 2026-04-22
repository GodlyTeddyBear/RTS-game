--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local MapTypes = require(ReplicatedStorage.Contexts.Map.Types.MapTypes)

export type MapRootComponent = MapTypes.MapRootComponent
export type MapInstanceComponent = MapTypes.MapInstanceComponent
export type ZoneComponent = MapTypes.ZoneComponent
export type GoalComponent = MapTypes.GoalComponent
export type GoalZoneTag = MapTypes.GoalZoneTag

--[=[
	@class MapComponentRegistry
	Registers map ECS components and exposes ids for the Map context.
	@server
]=]
local MapComponentRegistry = {}
MapComponentRegistry.__index = MapComponentRegistry

local function _nameComponent(world: any, componentId: number, name: string)
	world:set(componentId, JECS.Name, name)
end

function MapComponentRegistry.new()
	local self = setmetatable({}, MapComponentRegistry)
	self._components = nil
	return self
end

function MapComponentRegistry:Init(registry: any, _name: string)
	local world = registry:Get("World")

	-- [AUTHORITATIVE] Runtime map root metadata.
	local mapRoot = world:component() :: MapRootComponent
	_nameComponent(world, mapRoot, "Map.MapRoot")

	-- [AUTHORITATIVE] Roblox model instance for the map root.
	local mapInstance = world:component() :: MapInstanceComponent
	_nameComponent(world, mapInstance, "Map.MapInstance")

	-- [AUTHORITATIVE] Zone marker instance reference.
	local zone = world:component() :: ZoneComponent
	_nameComponent(world, zone, "Map.Zone")

	-- [AUTHORITATIVE] Cached goal marker reference for fast lookup.
	local goal = world:component() :: GoalComponent
	_nameComponent(world, goal, "Map.Goal")

	local goalZoneTag = world:entity() :: GoalZoneTag
	_nameComponent(world, goalZoneTag, "Map.GoalZone")

	self._components = table.freeze({
		MapRootComponent = mapRoot,
		MapInstanceComponent = mapInstance,
		ZoneComponent = zone,
		GoalComponent = goal,
		GoalZoneTag = goalZoneTag,
		ChildOf = JECS.ChildOf,
	})
end

function MapComponentRegistry:GetComponents()
	return self._components
end

return MapComponentRegistry

