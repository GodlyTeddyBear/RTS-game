--!strict

--[=[
	@class VillagerGameObjectSyncService
	Syncs ECS entity state to Roblox model attributes; manages entity-to-instance mappings.
	@server
]=]

local VillagerGameObjectSyncService = {}
VillagerGameObjectSyncService.__index = VillagerGameObjectSyncService

export type TVillagerGameObjectSyncService = typeof(setmetatable({} :: {
	World: any,
	Components: any,
	EntityFactory: any,
	ModelFactory: any,
	EntityToInstance: { [any]: Model },
	InstanceToEntity: { [Model]: any },
}, VillagerGameObjectSyncService))

function VillagerGameObjectSyncService.new(): TVillagerGameObjectSyncService
	local self = setmetatable({}, VillagerGameObjectSyncService)
	self.EntityToInstance = {}
	self.InstanceToEntity = {}
	return self
end

function VillagerGameObjectSyncService:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.EntityFactory = registry:Get("VillagerEntityFactory")
	self.ModelFactory = registry:Get("VillagerModelFactory")
end

--[=[
	Syncs model positions from Roblox instances back into ECS entities.
	@within VillagerGameObjectSyncService
]=]
function VillagerGameObjectSyncService:PollPositions()
	-- Update ECS positions from current model transforms
	for entity, model in pairs(self.EntityToInstance) do
		if model.PrimaryPart then
			self.EntityFactory:UpdatePosition(entity, model:GetPivot())
		end
	end
end

--[=[
	Syncs all entities marked dirty to their linked models (applies attributes).
	@within VillagerGameObjectSyncService
]=]
function VillagerGameObjectSyncService:SyncDirtyEntities()
	for entity in self.World:query(self.Components.DirtyTag) do
		local success = pcall(function()
			self:_SyncEntity(entity)
		end)

		-- Remove dirty tag only if sync succeeds
		if success then
			self.World:remove(entity, self.Components.DirtyTag)
		end
	end
end

-- Applies entity state to model attributes.
function VillagerGameObjectSyncService:_SyncEntity(entity: any)
	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if modelRef then
		self:_TrackModel(entity, modelRef.Instance)
		self:_ApplyAttributes(entity, modelRef.Instance)
	end
end

-- Copies identity and visit state from ECS to model attributes.
function VillagerGameObjectSyncService:_ApplyAttributes(entity: any, model: Model)
	local identity = self.World:get(entity, self.Components.IdentityComponent)
	local visit = self.World:get(entity, self.Components.VisitComponent)
	if identity then
		model:SetAttribute("VillagerId", identity.VillagerId)
		model:SetAttribute("VillagerType", identity.BehaviorType)
		model:SetAttribute("MerchantShopId", identity.MerchantShopId)
	end
	if visit then
		model:SetAttribute("VillagerState", visit.State)
		model:SetAttribute("TargetUserId", visit.TargetUserId)
		model:SetAttribute("OfferId", visit.OfferId)
	end
end

--[=[
	Registers an entity-model mapping for tracking.
	@within VillagerGameObjectSyncService
	@param entity any -- ECS entity
]=]
function VillagerGameObjectSyncService:RegisterEntity(entity: any)
	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if modelRef then
		self:_TrackModel(entity, modelRef.Instance)
	end
end

--[=[
	Gets the Roblox model instance for an entity.
	@within VillagerGameObjectSyncService
	@param entity any -- ECS entity
	@return Model? -- Model or nil if not linked
]=]
function VillagerGameObjectSyncService:GetInstanceForEntity(entity: any): Model?
	return self.EntityToInstance[entity]
end

--[=[
	Deletes an entity and its linked model.
	@within VillagerGameObjectSyncService
	@param entity any -- ECS entity
]=]
function VillagerGameObjectSyncService:DeleteEntity(entity: any)
	local model = self.EntityToInstance[entity]
	if model then
		self.EntityToInstance[entity] = nil
		self.InstanceToEntity[model] = nil
		self.ModelFactory:DestroyModel(model)
	end

	if self.World:get(entity, self.Components.ModelRefComponent) then
		self.World:remove(entity, self.Components.ModelRefComponent)
	end
end

-- Adds bidirectional mapping between entity and model.
function VillagerGameObjectSyncService:_TrackModel(entity: any, model: Model)
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity
end

return VillagerGameObjectSyncService
