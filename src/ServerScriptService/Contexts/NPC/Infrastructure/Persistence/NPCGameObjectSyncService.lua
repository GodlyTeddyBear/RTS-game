--!strict

--[=[
	@class NPCGameObjectSyncService
	Syncs NPC ECS entities with Roblox workspace models (animation, position, status).
	Maintains bidirectional entity-model mappings for cleanup and state propagation.
	@server
]=]

--[[
    NPCGameObjectSyncService - Syncs combat ECS entities to Roblox workspace models.

    Responsibilities:
    - Query dirty NPC entities
    - Read model position and write it into PositionComponent (model is source of truth)
    - Sync animation state from CombatStateComponent onto the model
    - Maintain Entity <-> Model mapping
    - Clean up models when entities are deleted

    Position flow: Model (Humanoid/SimplePath moves it) → PositionComponent (read-only ECS cache)
    The sync service NEVER moves the model. It only reads the model's current CFrame.

    Note: Unlike Worker's GameObjectSyncService, this does NOT create models on dirty.
    Models are created explicitly by SpawnAdventurerParty/SpawnEnemyWave and the
    ModelRefComponent is set via NPCEntityFactory:SetModelRef.

    Pattern: Infrastructure layer service, runs every Heartbeat
]]

local NPCGameObjectSyncService = {}
NPCGameObjectSyncService.__index = NPCGameObjectSyncService

export type TNPCGameObjectSyncService = typeof(setmetatable({} :: {
	World: any,
	Components: any,
	NPCModelFactory: any,
	NPCEntityFactory: any,
	RevealAdapter: any,
	EntityToInstance: { [any]: Model },
	InstanceToEntity: { [Model]: any },
	_LastAnimState: { [any]: string },
}, NPCGameObjectSyncService))

function NPCGameObjectSyncService.new(): TNPCGameObjectSyncService
	local self = setmetatable({}, NPCGameObjectSyncService)
	-- Bidirectional mapping for cleanup
	self.EntityToInstance = {} :: { [any]: Model }
	self.InstanceToEntity = {} :: { [Model]: any }
	self._LastAnimState = {} :: { [any]: string }
	return self
end

--[=[
	Initialize sync service with JECS world and factories.
	@within NPCGameObjectSyncService
	@param registry any -- Registry with world, components, and factory references
]=]
function NPCGameObjectSyncService:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.NPCModelFactory = registry:Get("NPCModelFactory")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.RevealAdapter = registry:Get("NPCRevealAdapter")
end

--[=[
	Poll all tracked model positions and update PositionComponent (read-only cache).
	Called every Heartbeat; model is the source of truth.
	@within NPCGameObjectSyncService
]=]
function NPCGameObjectSyncService:PollPositions()
	-- Update entity position from model's current CFrame (read only, no sync loop)
	for entity, model in pairs(self.EntityToInstance) do
		self:_PollEntityPosition(entity, model)
	end
end

function NPCGameObjectSyncService:_PollEntityPosition(entity: any, model: Model)
	local success, err = pcall(function()
		if model.PrimaryPart then
			self.NPCEntityFactory:UpdatePosition(entity, model:GetPivot())
		end
	end)
	if not success then
		warn("[NPCGameObjectSync] Failed to poll position:", entity, "-", err)
	end
end

--[=[
	Sync animation state from ECS components onto all dirty entities' models.
	Called every Heartbeat; clears DirtyTag after sync.
	@within NPCGameObjectSyncService
]=]
function NPCGameObjectSyncService:SyncDirtyEntities()
	-- Iterate all entities marked dirty (component state changed)
	for entity in self.World:query(self.Components.DirtyTag) do
		local success, err = pcall(function()
			self:_SyncRevealState(entity)
		end)

		if not success then
			warn("[NPCGameObjectSync] Failed to sync entity:", entity, "-", err)
		else
			-- Clear dirty tag after successful sync
			self.World:remove(entity, self.Components.DirtyTag)
		end
	end
end

--[=[
	Register an entity-model mapping when ModelRefComponent is first assigned.
	@within NPCGameObjectSyncService
	@param entity any -- JECS entity ID
]=]
function NPCGameObjectSyncService:RegisterEntity(entity: any)
	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if not modelRef or not modelRef.Instance then
		return
	end
	local model = modelRef.Instance
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity
end

function NPCGameObjectSyncService:_SyncRevealState(entity: any)
	-- Resolve model from entity mapping (lazily register if not yet tracked)
	local model = self:_ResolveModel(entity)
	if not model then return end

	local previousAnimationState = model:GetAttribute("AnimationState")
	self.RevealAdapter:Apply(entity, model)
	self._LastAnimState[entity] = model:GetAttribute("AnimationState") or previousAnimationState or "Idle"
end

function NPCGameObjectSyncService:_ResolveModel(entity: any): Model?
	local model = self.EntityToInstance[entity]
	if model then return model end
	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if not modelRef or not modelRef.Instance then return nil end
	model = modelRef.Instance
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity
	return model
end

--[=[
	Get the Roblox Model instance associated with an entity.
	@within NPCGameObjectSyncService
	@param entity any -- JECS entity ID
	@return Model? -- Model instance, or nil if none exists
]=]
function NPCGameObjectSyncService:GetInstanceForEntity(entity: any): Model?
	return self.EntityToInstance[entity]
end

--[=[
	Destroy the model and clean up bidirectional entity-model mappings.
	Call before deleting the entity from the JECS world.
	@within NPCGameObjectSyncService
	@param entity any -- JECS entity ID
]=]
function NPCGameObjectSyncService:DeleteEntity(entity: any)
	local instance = self.EntityToInstance[entity]

	if instance then
		self.NPCModelFactory:DestroyModel(instance)
		self.EntityToInstance[entity] = nil
		self.InstanceToEntity[instance] = nil
		self._LastAnimState[entity] = nil
	end

	-- Remove ModelRefComponent if exists
	if self.World:get(entity, self.Components.ModelRefComponent) then
		self.World:remove(entity, self.Components.ModelRefComponent)
	end
end

--[=[
	Clear all entity-model mappings for a user (bulk cleanup on player disconnect).
	@within NPCGameObjectSyncService
	@param userId number -- Player ID to clean up
]=]
function NPCGameObjectSyncService:CleanupUser(userId: number)
	local userEntities = self.NPCEntityFactory:QueryAllEntities(userId)
	for _, entity in ipairs(userEntities) do
		local instance = self.EntityToInstance[entity]
		if instance then
			self.EntityToInstance[entity] = nil
			self.InstanceToEntity[instance] = nil
			self._LastAnimState[entity] = nil
		end
	end
end

return NPCGameObjectSyncService
