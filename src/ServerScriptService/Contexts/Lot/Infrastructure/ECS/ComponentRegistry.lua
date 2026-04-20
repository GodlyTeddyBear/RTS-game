--!strict

--[[
	Component Registry - Defines all Lot ECS components.

	Responsibilities:
	- Define component types in JECS world
	- Provide component references to other services

	Pattern: Created once during LotContext initialization
]]

--[=[
	@class ComponentRegistry
	Registers and manages all ECS component types for the Lot context.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local JECS = require(Packages.JECS)
local ComponentTypes = require(ReplicatedStorage.Contexts.Lot.Types.ComponentTypes)

export type TLotComponent = ComponentTypes.TLotComponent
export type TPositionComponent = ComponentTypes.TPositionComponent
export type TGameObjectComponent = ComponentTypes.TGameObjectComponent
export type TZoneComponent = ComponentTypes.TZoneComponent
export type TMinesComponent = ComponentTypes.TMinesComponent
export type TFarmComponent = ComponentTypes.TFarmComponent
export type TGardenComponent = ComponentTypes.TGardenComponent
export type TForestComponent = ComponentTypes.TForestComponent
export type TForgeComponent = ComponentTypes.TForgeComponent
export type TBreweryComponent = ComponentTypes.TBreweryComponent
export type TTailorShopComponent = ComponentTypes.TTailorShopComponent
export type TDirtyTag = ComponentTypes.TDirtyTag

local ComponentRegistry = {}
ComponentRegistry.__index = ComponentRegistry

--[=[
	Create a new ComponentRegistry instance.
	@within ComponentRegistry
	@return ComponentRegistry -- Service instance
]=]
function ComponentRegistry.new()
	local self = setmetatable({}, ComponentRegistry)
	return self
end

--[=[
	Initialize and register all component types in the JECS world.
	@within ComponentRegistry
	@param registry any -- Registry to resolve dependencies from
]=]
function ComponentRegistry:Init(registry: any)
	local world = registry:Get("World")
	self.World = world

	-- Define all components in JECS world
	self.LotComponent = world:component() :: TLotComponent
	world:set(self.LotComponent, JECS.Name, "Lot")
	self.PositionComponent = world:component() :: TPositionComponent
	world:set(self.PositionComponent, JECS.Name, "Position")
	self.GameObjectComponent = world:component() :: TGameObjectComponent
	world:set(self.GameObjectComponent, JECS.Name, "GameObject")
	self.ZoneComponent = world:component() :: TZoneComponent
	world:set(self.ZoneComponent, JECS.Name, "Zone")
	self.MinesComponent = world:component() :: TMinesComponent
	world:set(self.MinesComponent, JECS.Name, "Mines")
	self.FarmComponent = world:component() :: TFarmComponent
	world:set(self.FarmComponent, JECS.Name, "Farm")
	self.GardenComponent = world:component() :: TGardenComponent
	world:set(self.GardenComponent, JECS.Name, "Garden")
	self.ForestComponent = world:component() :: TForestComponent
	world:set(self.ForestComponent, JECS.Name, "Forest")
	self.ForgeComponent = world:component() :: TForgeComponent
	world:set(self.ForgeComponent, JECS.Name, "Forge")
	self.BreweryComponent = world:component() :: TBreweryComponent
	world:set(self.BreweryComponent, JECS.Name, "Brewery")
	self.TailorShopComponent = world:component() :: TTailorShopComponent
	world:set(self.TailorShopComponent, JECS.Name, "TailorShop")
	self.DirtyTag = world:component() :: TDirtyTag
	world:set(self.DirtyTag, JECS.Name, "Dirty")
	self.EntityTag = world:component()
	world:set(self.EntityTag, JECS.Name, "Entity")

	-- Built-in JECS exclusive relationship for parent-child hierarchies
	self.ChildOf = JECS.ChildOf
end

return ComponentRegistry
