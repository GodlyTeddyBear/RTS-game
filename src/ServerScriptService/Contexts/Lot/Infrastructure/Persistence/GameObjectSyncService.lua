--!strict

--[[
	Lot GameObject Sync Service - Sync ECS entities to Roblox workspace

	Responsibility: Detect DirtyTag on entities, create/update Roblox models.
	Runs every Heartbeat to sync lot entities to the workspace.
]]

--[=[
	@class GameObjectSyncService
	Syncs ECS entities marked with DirtyTag to Roblox workspace instances.
	@server
]=]

local ComponentRegistry = require(script.Parent.Parent.ECS.ComponentRegistry)

export type TGameObjectComponent = ComponentRegistry.TGameObjectComponent

local GameObjectSyncService = {}
GameObjectSyncService.__index = GameObjectSyncService

--[=[
	Create a new GameObjectSyncService instance.
	@within GameObjectSyncService
	@return GameObjectSyncService -- Service instance
]=]
function GameObjectSyncService.new()
	local self = setmetatable({}, GameObjectSyncService)

	-- Bidirectional mapping for cleanup
	self.EntityToInstance = {} :: { [any]: Model }
	self.InstanceToEntity = {} :: { [Model]: any }

	return self
end

--[=[
	Initialize with injected dependencies.
	@within GameObjectSyncService
	@param registry any -- Registry to resolve dependencies from
]=]
function GameObjectSyncService:Init(registry: any)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.GameObjectFactory = registry:Get("GameObjectFactory")
	self.EntityFactory = registry:Get("LotEntityFactory")
end

--[=[
	Sync all entities marked with DirtyTag to workspace.
	Called every Heartbeat by the Planck scheduler.
	@within GameObjectSyncService
]=]
function GameObjectSyncService:SyncDirtyEntities()
	-- Query all dirty entities
	for entity in self.World:query(self.Components.DirtyTag) do
		local success, err = pcall(function()
			self:_SyncEntity(entity)
		end)

		if not success then
			warn("[LotGameObjectSync] Failed to sync entity:", entity, "-", err)
			-- Entity stays dirty, will retry next frame
		else
			-- Clear dirty flag after successful sync
			self.World:remove(entity, self.Components.DirtyTag)
		end
	end
end

-- Sync a single entity to workspace. Creates GameObject if doesn't exist, updates if exists.
function GameObjectSyncService:_SyncEntity(entity: any)
	local gameObject = self.World:get(entity, self.Components.GameObjectComponent)

	-- Create GameObject if doesn't exist
	if not gameObject then
		self:_CreateGameObjectForEntity(entity)
		return
	end

	-- Update existing GameObject from components
	self:_UpdateGameObjectFromComponents(entity, gameObject.Instance)
end

-- Create a new GameObject for an entity. Fetches lot data, creates model from factory, and registers zone entities.
function GameObjectSyncService:_CreateGameObjectForEntity(entity: any)
	local lot = self.World:get(entity, self.Components.LotComponent)
	local position = self.World:get(entity, self.Components.PositionComponent)

	if not lot then
		warn("[LotGameObjectSync] Entity missing LotComponent, cannot create GameObject")
		return
	end

	-- Create model from template (use "Default" type)
	local model = self.GameObjectFactory:CreateLotModel("Default", lot.LotId)

	-- Set initial CFrame
	if position then
		self.GameObjectFactory:UpdateLotCFrame(model, position.CFrameValue)
	end

	-- Store GameObject component
	self.World:set(entity, self.Components.GameObjectComponent, {
		Instance = model,
	} :: TGameObjectComponent)

	-- Update mappings
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity

	-- Create zone sub-entities (ProductionEntity, MinesEntity) as children of this lot
	self.EntityFactory:CreateZoneEntities(entity, model)
end

-- Update an existing GameObject from entity components. Currently handles CFrame updates.
function GameObjectSyncService:_UpdateGameObjectFromComponents(entity: any, model: Model)
	local position = self.World:get(entity, self.Components.PositionComponent)

	-- Update CFrame if changed
	if position then
		self.GameObjectFactory:UpdateLotCFrame(model, position.CFrameValue)
	end
end

--[=[
	Delete entity and clean up GameObject. Must be called BEFORE deleting the entity from JECS world.
	@within GameObjectSyncService
	@param entity any -- The JECS entity to delete
]=]
function GameObjectSyncService:DeleteEntity(entity: any)
	local instance = self.EntityToInstance[entity]

	if instance then
		-- Destroy GameObject
		self.GameObjectFactory:DestroyLotModel(instance)

		-- Clear mappings
		self.EntityToInstance[entity] = nil
		self.InstanceToEntity[instance] = nil
	end

	-- Remove GameObject component if exists
	if self.World:get(entity, self.Components.GameObjectComponent) then
		self.World:remove(entity, self.Components.GameObjectComponent)
	end
end

return GameObjectSyncService
