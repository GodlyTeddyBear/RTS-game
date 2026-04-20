--!strict

--[=[
	@class VillagerEntityFactory
	Factory for creating, updating, and querying villager entities in the ECS world.
	@server
]=]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)
local VillagerTypes = require(ReplicatedStorage.Contexts.Villager.Types.VillagerTypes)

type TVillagerArchetype = VillagerTypes.TVillagerArchetype
type TPositionComponent = VillagerTypes.TPositionComponent
type TVillagerIdentityComponent = VillagerTypes.TVillagerIdentityComponent
type TModelRefComponent = VillagerTypes.TModelRefComponent
type TRouteComponent = VillagerTypes.TRouteComponent
type TVisitComponent = VillagerTypes.TVisitComponent
type TCleanupComponent = VillagerTypes.TCleanupComponent

local VillagerEntityFactory = {}
VillagerEntityFactory.__index = VillagerEntityFactory

export type TVillagerEntityFactory = typeof(setmetatable({} :: {
	World: any,
	Components: any,
}, VillagerEntityFactory))

function VillagerEntityFactory.new(): TVillagerEntityFactory
	return setmetatable({}, VillagerEntityFactory)
end

function VillagerEntityFactory:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

--[=[
	Creates a new villager entity with all required components.
	@within VillagerEntityFactory
	@param archetype TVillagerArchetype -- Archetype config (Customer, Merchant, etc.)
	@param spawnCFrame CFrame -- Initial world position
	@return (any, string) -- ECS entity and unique villager ID
]=]
function VillagerEntityFactory:CreateVillager(archetype: TVillagerArchetype, spawnCFrame: CFrame): (any, string)
	local villagerId = HttpService:GenerateGUID(false)
	local entity = self.World:entity()
	local world = self.World :: any

	-- Set Identity (who is this villager?)
	world:set(entity, self.Components.IdentityComponent, {
		VillagerId = villagerId,
		ArchetypeId = archetype.Id,
		DisplayName = archetype.DisplayName,
		BehaviorType = archetype.BehaviorType,
		MerchantShopId = archetype.MerchantShopId,
	} :: TVillagerIdentityComponent)

	-- Set Position (where is it?)
	world:set(entity, self.Components.PositionComponent, {
		CFrame = spawnCFrame,
	} :: TPositionComponent)

	-- Set Route (path state)
	world:set(entity, self.Components.RouteComponent, {
		CurrentTarget = nil,
		PathStatus = "Idle",
		PathStartedAt = 0,
	} :: TRouteComponent)

	-- Set Visit (customer state machine)
	world:set(entity, self.Components.VisitComponent, {
		State = "Spawning",
		TargetUserId = nil,
		Entrance = nil,
		WaitPoint = nil,
		ExitPoint = nil,
		OfferId = nil,
		LastStateChangedAt = os.clock(),
	} :: TVisitComponent)

	-- Tag by type (Customer/Merchant)
	if archetype.BehaviorType == "Merchant" then
		world:add(entity, self.Components.MerchantTag)
	else
		world:add(entity, self.Components.CustomerTag)
	end

	-- Mark as dirty for initial sync; set ID tags for debugging
	world:add(entity, self.Components.DirtyTag)
	world:set(entity, self.Components.EntityTag, `Villager:{villagerId}`)
	world:set(entity, JECS.Name, `Villager:{villagerId}`)

	return entity, villagerId
end

--[=[
	Links a Roblox model instance to the villager entity.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param model Model -- Roblox model to associate
]=]
function VillagerEntityFactory:SetModelRef(entity: any, model: Model)
	self.World:set(entity, self.Components.ModelRefComponent, {
		Instance = model,
	} :: TModelRefComponent)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Updates the villager's position in the ECS world.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param cframe CFrame -- New position
]=]
function VillagerEntityFactory:UpdatePosition(entity: any, cframe: CFrame)
	self.World:set(entity, self.Components.PositionComponent, {
		CFrame = cframe,
	} :: TPositionComponent)
end

--[=[
	Marks the villager as actively pathfinding toward a target.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param target Vector3 -- Destination position
]=]
function VillagerEntityFactory:SetPathMoving(entity: any, target: Vector3)
	self.World:set(entity, self.Components.RouteComponent, {
		CurrentTarget = target,
		PathStatus = "Moving",
		PathStartedAt = os.clock(),
	} :: TRouteComponent)
end

--[=[
	Updates the pathfinding status (Moving, Reached, Failed, Idle).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param status TPathStatus -- Path status
]=]
function VillagerEntityFactory:SetPathStatus(entity: any, status: VillagerTypes.TPathStatus)
	local route = self.World:get(entity, self.Components.RouteComponent)
	if not route then
		return
	end

	local updated = table.clone(route)
	updated.PathStatus = status
	self.World:set(entity, self.Components.RouteComponent, updated)
end

--[=[
	Assigns the target lot and route markers for a customer visit.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param targetUserId number -- Player to visit
	@param entrance BasePart -- Entry point marker
	@param waitPoint BasePart -- Wait location marker
	@param exitPoint BasePart -- Exit location marker
]=]
function VillagerEntityFactory:SetVisitTarget(entity: any, targetUserId: number, entrance: BasePart, waitPoint: BasePart, exitPoint: BasePart)
	local visit = self.World:get(entity, self.Components.VisitComponent)
	if not visit then
		return
	end

	local updated = table.clone(visit)
	updated.TargetUserId = targetUserId
	updated.Entrance = entrance
	updated.WaitPoint = waitPoint
	updated.ExitPoint = exitPoint
	updated.LastStateChangedAt = os.clock()
	self.World:set(entity, self.Components.VisitComponent, updated)
end

--[=[
	Transitions the visit state machine (Spawning → WalkingToShop → WaitingForOffer → Departing → Complete).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param state TVillagerState -- New state
]=]
function VillagerEntityFactory:SetVisitState(entity: any, state: VillagerTypes.TVillagerState)
	local visit = self.World:get(entity, self.Components.VisitComponent)
	if not visit then
		return
	end

	local updated = table.clone(visit)
	updated.State = state
	updated.LastStateChangedAt = os.clock()
	self.World:set(entity, self.Components.VisitComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Records the commission offer ID for the current visit.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param offerId string? -- Commission offer ID or nil to clear
]=]
function VillagerEntityFactory:SetOfferId(entity: any, offerId: string?)
	local visit = self.World:get(entity, self.Components.VisitComponent)
	if not visit then
		return
	end

	local updated = table.clone(visit)
	updated.OfferId = offerId
	self.World:set(entity, self.Components.VisitComponent, updated)
	self.World:add(entity, self.Components.DirtyTag)
end

--[=[
	Marks the entity for cleanup on next behavior tick.
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@param reason string -- Cleanup reason (for logging)
]=]
function VillagerEntityFactory:RequestCleanup(entity: any, reason: string)
	self.World:set(entity, self.Components.CleanupComponent, {
		Reason = reason,
		RequestedAt = os.clock(),
	} :: TCleanupComponent)
	self:SetVisitState(entity, "Complete")
end

--[=[
	Gets identity component (archetype, name, etc.).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@return TVillagerIdentityComponent? -- Identity or nil if not present
]=]
function VillagerEntityFactory:GetIdentity(entity: any): TVillagerIdentityComponent?
	return self.World:get(entity, self.Components.IdentityComponent)
end

--[=[
	Gets model reference component (linked Roblox model).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@return TModelRefComponent? -- Model reference or nil if not linked
]=]
function VillagerEntityFactory:GetModelRef(entity: any): TModelRefComponent?
	return self.World:get(entity, self.Components.ModelRefComponent)
end

--[=[
	Gets route component (pathfinding state).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@return TRouteComponent? -- Route state or nil if not present
]=]
function VillagerEntityFactory:GetRoute(entity: any): TRouteComponent?
	return self.World:get(entity, self.Components.RouteComponent)
end

--[=[
	Gets visit component (customer state machine).
	@within VillagerEntityFactory
	@param entity any -- ECS entity
	@return TVisitComponent? -- Visit state or nil if not present
]=]
function VillagerEntityFactory:GetVisit(entity: any): TVisitComponent?
	return self.World:get(entity, self.Components.VisitComponent)
end

--[=[
	Looks up an entity by villager ID.
	@within VillagerEntityFactory
	@param villagerId string -- Unique villager ID
	@return any? -- Entity or nil if not found
]=]
function VillagerEntityFactory:GetEntityByVillagerId(villagerId: string): any?
	for entity in self.World:query(self.Components.IdentityComponent) do
		local identity = self:GetIdentity(entity)
		if identity and identity.VillagerId == villagerId then
			return entity
		end
	end

	return nil
end

--[=[
	Queries all customer entities.
	@within VillagerEntityFactory
	@return { any } -- List of customer entities
]=]
function VillagerEntityFactory:QueryCustomers(): { any }
	return self:_QueryEntities(self.Components.CustomerTag, self.Components.IdentityComponent)
end

--[=[
	Queries all merchant entities.
	@within VillagerEntityFactory
	@return { any } -- List of merchant entities
]=]
function VillagerEntityFactory:QueryMerchants(): { any }
	return self:_QueryEntities(self.Components.MerchantTag, self.Components.IdentityComponent)
end

--[=[
	Queries all villager entities.
	@within VillagerEntityFactory
	@return { any } -- List of all entities with Identity
]=]
function VillagerEntityFactory:QueryAll(): { any }
	return self:_QueryEntities(self.Components.IdentityComponent)
end

--[=[
	Queries all entities marked for cleanup.
	@within VillagerEntityFactory
	@return { any } -- List of entities pending removal
]=]
function VillagerEntityFactory:QueryCleanup(): { any }
	return self:_QueryEntities(self.Components.CleanupComponent)
end

-- Helper to collect all entities matching given components into a list.
function VillagerEntityFactory:_QueryEntities(...): { any }
	local entities = {}
	for entity in self.World:query(...) do
		table.insert(entities, entity)
	end
	return entities
end

--[=[
	Removes an entity from the world.
	@within VillagerEntityFactory
	@param entity any -- ECS entity to delete
]=]
function VillagerEntityFactory:DeleteEntity(entity: any)
	self.World:delete(entity)
end

return VillagerEntityFactory
