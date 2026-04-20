--!strict

--[=[
	@class VillagerComponentRegistry
	Registers and manages ECS component and tag definitions for villagers.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local VillagerTypes = require(ReplicatedStorage.Contexts.Villager.Types.VillagerTypes)

export type TVillagerIdentityComponent = VillagerTypes.TVillagerIdentityComponent
export type TPositionComponent = VillagerTypes.TPositionComponent
export type TModelRefComponent = VillagerTypes.TModelRefComponent
export type TRouteComponent = VillagerTypes.TRouteComponent
export type TVisitComponent = VillagerTypes.TVisitComponent
export type TCleanupComponent = VillagerTypes.TCleanupComponent
export type TDirtyTag = VillagerTypes.TDirtyTag

local VillagerComponentRegistry = {}
VillagerComponentRegistry.__index = VillagerComponentRegistry

export type TVillagerComponentRegistry = typeof(setmetatable({} :: {
	World: any,
	IdentityComponent: any,
	PositionComponent: any,
	ModelRefComponent: any,
	RouteComponent: any,
	VisitComponent: any,
	CleanupComponent: any,
	CustomerTag: any,
	MerchantTag: any,
	DirtyTag: any,
	EntityTag: any,
}, VillagerComponentRegistry))

function VillagerComponentRegistry.new(): TVillagerComponentRegistry
	return setmetatable({}, VillagerComponentRegistry)
end

-- Initializes all component and tag definitions in the JECS world.
function VillagerComponentRegistry:Init(registry: any)
	local world = registry:Get("World")
	self.World = world

	-- Data components (store state)
	self.IdentityComponent = world:component()
	world:set(self.IdentityComponent, JECS.Name, "VillagerIdentity")
	self.PositionComponent = world:component()
	world:set(self.PositionComponent, JECS.Name, "Position")
	self.ModelRefComponent = world:component()
	world:set(self.ModelRefComponent, JECS.Name, "ModelRef")
	self.RouteComponent = world:component()
	world:set(self.RouteComponent, JECS.Name, "Route")
	self.VisitComponent = world:component()
	world:set(self.VisitComponent, JECS.Name, "Visit")
	self.CleanupComponent = world:component()
	world:set(self.CleanupComponent, JECS.Name, "Cleanup")

	-- Tags (marks entity for filtering)
	self.CustomerTag = world:component()
	world:set(self.CustomerTag, JECS.Name, "Customer")
	self.MerchantTag = world:component()
	world:set(self.MerchantTag, JECS.Name, "Merchant")
	self.DirtyTag = world:component()
	world:set(self.DirtyTag, JECS.Name, "Dirty")
	self.EntityTag = world:component()
	world:set(self.EntityTag, JECS.Name, "Entity")
end

return VillagerComponentRegistry
