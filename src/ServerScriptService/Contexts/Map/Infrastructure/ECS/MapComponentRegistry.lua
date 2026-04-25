--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local BaseECSComponentRegistry = require(ReplicatedStorage.Utilities.BaseECSComponentRegistry)
local MapTypes = require(ReplicatedStorage.Contexts.Map.Types.MapTypes)

export type MapRootComponent = MapTypes.MapRootComponent
export type MapInstanceComponent = MapTypes.MapInstanceComponent
export type ZoneComponent = MapTypes.ZoneComponent
export type GoalComponent = MapTypes.GoalComponent
export type GoalZoneTag = MapTypes.GoalZoneTag
export type SpawnComponent = MapTypes.SpawnComponent
export type SpawnZoneTag = MapTypes.SpawnZoneTag
export type BaseComponent = MapTypes.BaseComponent
export type BaseZoneTag = MapTypes.BaseZoneTag

--[=[
	@class MapComponentRegistry
	Registers map ECS components and exposes ids for the Map context.
	@server
]=]
local MapComponentRegistry = {}
MapComponentRegistry.__index = MapComponentRegistry
setmetatable(MapComponentRegistry, { __index = BaseECSComponentRegistry })

function MapComponentRegistry.new()
	return setmetatable(BaseECSComponentRegistry.new("Map"), MapComponentRegistry)
end

function MapComponentRegistry:_RegisterComponents(_registry: any, _name: string)
	-- [AUTHORITATIVE] Runtime map root metadata.
	self:RegisterComponent("MapRootComponent", "Map.MapRoot", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Roblox model instance for the map root.
	self:RegisterComponent("MapInstanceComponent", "Map.MapInstance", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Zone marker instance reference.
	self:RegisterComponent("ZoneComponent", "Map.Zone", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Cached goal marker reference for fast lookup.
	self:RegisterComponent("GoalComponent", "Map.Goal", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Cached spawn marker reference for fast lookup.
	self:RegisterComponent("SpawnComponent", "Map.Spawn", "AUTHORITATIVE")
	-- [AUTHORITATIVE] Cached base marker/model and anchor reference for run objective setup.
	self:RegisterComponent("BaseComponent", "Map.Base", "AUTHORITATIVE")

	self:RegisterTag("GoalZoneTag", "Map.GoalZoneTag")
	self:RegisterTag("SpawnZoneTag", "Map.SpawnZoneTag")
	self:RegisterTag("BaseZoneTag", "Map.BaseZoneTag")
	self:RegisterExternal("ChildOf", JECS.ChildOf)
end

return MapComponentRegistry
