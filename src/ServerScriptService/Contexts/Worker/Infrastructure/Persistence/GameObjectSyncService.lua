--!strict

--[[
    GameObject Sync Service - Syncs ECS entities to Roblox workspace instances.

    Responsibilities:
    - Query dirty entities
    - Create GameObjects for new entities
    - Update existing GameObjects from components
    - Maintain Entity ↔ GameObject mapping
    - Clean up GameObjects when entities are deleted

    Pattern: Infrastructure layer service, runs every Heartbeat
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Catch = Result.Catch

local ComponentRegistry = require(script.Parent.Parent.ECS.ComponentRegistry)

export type TGameObjectComponent = ComponentRegistry.TGameObjectComponent

local GameObjectSyncService = {}
GameObjectSyncService.__index = GameObjectSyncService

export type TGameObjectSyncService = typeof(setmetatable({} :: {
	World: any,
	Components: any,
	GameObjectFactory: any,
	RevealAdapter: any,
	EntityToInstance: { [any]: Model },
	InstanceToEntity: { [Model]: any },
	_equippedState: { [any]: string? },
}, GameObjectSyncService))

function GameObjectSyncService.new(): TGameObjectSyncService
	local self = setmetatable({}, GameObjectSyncService)

	-- Bidirectional mapping for cleanup
	self.EntityToInstance = {} :: { [any]: Model }
	self.InstanceToEntity = {} :: { [Model]: any }

	-- Tracks the last toolId equipped per entity to detect equip/unequip transitions
	self._equippedState = {} :: { [any]: string? }

	return self
end

function GameObjectSyncService:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.GameObjectFactory = registry:Get("GameObjectFactory")
	self.RevealAdapter = registry:Get("WorkerRevealAdapter")
end

--[[
    Sync all entities marked with DirtyTag.
    Called every Heartbeat.
]]
function GameObjectSyncService:SyncDirtyEntities()
	-- Query all dirty entities
	for entity in self.World:query(self.Components.DirtyTag) do
		local result = Catch(function()
			self:_SyncEntity(entity)
		end, "Worker:GameObjectSyncService:SyncDirtyEntities")

		if result.success then
			self.World:remove(entity, self.Components.DirtyTag)
		end
	end
end

--[[
    Sync a single entity to workspace.
    Creates GameObject if doesn't exist, updates if exists.
]]
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

--[[
    Create a new GameObject for an entity.
]]
function GameObjectSyncService:_CreateGameObjectForEntity(entity: any)
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	local position = self.World:get(entity, self.Components.PositionComponent)
	local assignment = self.World:get(entity, self.Components.AssignmentComponent)

	if not worker then
		warn("[GameObjectSync] Entity missing WorkerComponent, cannot create GameObject")
		return
	end

	-- Use occupation as the model template; reveal data is applied separately.
	local occupation = assignment and assignment.Role or "Undecided"
	local model = self.GameObjectFactory:CreateWorkerModel(occupation, worker.Id)
	self.RevealAdapter:Apply(entity, model)

	-- Set initial position (and facing direction if stored)
	if position then
		local pos = Vector3.new(position.X, position.Y, position.Z)
		local lookAt = (position.LookAtX and position.LookAtY and position.LookAtZ)
			and Vector3.new(position.LookAtX, position.LookAtY, position.LookAtZ)
			or nil
		self.GameObjectFactory:UpdateWorkerPosition(model, pos, lookAt)
	end

	-- Set initial visuals
	self.GameObjectFactory:UpdateWorkerVisuals(model, worker)

	-- Store GameObject component
	self.World:set(entity, self.Components.GameObjectComponent, {
		Instance = model,
	} :: TGameObjectComponent)

	-- Update mappings
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity

	-- Attach any persisted equipment immediately
	self:_SyncEquipment(entity, model)

	-- If entity is actively mining, set animation state (StartMining may have been
	-- called before the model existed, so the attribute was never set)
	local miningState = self.World:get(entity, self.Components.MiningStateComponent)
	if miningState then
		self.RevealAdapter:Apply(entity, model)
	end
end

--[[
    Update an existing GameObject from components.
]]
function GameObjectSyncService:_UpdateGameObjectFromComponents(entity: any, model: Model)
	local worker = self.World:get(entity, self.Components.WorkerComponent)

	if not worker then
		warn("[GameObjectSync] Entity missing WorkerComponent during update")
		return
	end

	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	model = self:_ReplaceModelIfNeeded(entity, model, worker, assignment)

	-- Update visuals (level, XP bar)
	self.GameObjectFactory:UpdateWorkerVisuals(model, worker)

	-- Sync revealed attributes/tags so client animation and sound systems stay indexed.
	self.RevealAdapter:Apply(entity, model)

	-- Position is driven by explicit teleports (UpdatePosition), not the sync loop.
	-- PositionComponent is a read value reflecting the instance's actual position.

	-- Sync tool attachment (equip/unequip transitions)
	self:_SyncEquipment(entity, model)
end

function GameObjectSyncService:_ReplaceModelIfNeeded(entity: any, model: Model, worker: any, assignment: any): Model
	if not assignment then
		return model
	end

	local desiredTemplate = assignment.Role or "Undecided"
	local currentTemplate = model:GetAttribute("ModelTemplate")
	if currentTemplate == desiredTemplate then
		return model
	end

	local previousPivot = model:GetPivot()

	self.GameObjectFactory:DestroyWorkerModel(model)
	self.InstanceToEntity[model] = nil

	local replacementModel = self.GameObjectFactory:CreateWorkerModel(desiredTemplate, worker.Id)
	replacementModel:PivotTo(previousPivot)

	self.World:set(entity, self.Components.GameObjectComponent, {
		Instance = replacementModel,
	} :: TGameObjectComponent)
	self.RevealAdapter:Apply(entity, replacementModel)

	self.EntityToInstance[entity] = replacementModel
	self.InstanceToEntity[replacementModel] = entity

	-- Force re-attachment after replacement even if the equipped tool ID did not change.
	self._equippedState[entity] = nil

	return replacementModel
end

--[[
    Sync equipment state for an entity onto its model.
    Compares the current EquipmentComponent against the last known state
    and calls AttachTool / DetachTool only when the state has changed.
]]
function GameObjectSyncService:_SyncEquipment(entity: any, model: Model)
	local equipment = self.World:get(entity, self.Components.EquipmentComponent)
	local currentToolId: string? = equipment and equipment.ToolId or nil
	local lastToolId: string? = self._equippedState[entity]

	if currentToolId == lastToolId then
		return -- No change
	end

	if currentToolId then
		self.GameObjectFactory:AttachTool(model, currentToolId)
	else
		self.GameObjectFactory:DetachTool(model)
	end

	self._equippedState[entity] = currentToolId
end

--[[
    Get the Roblox Model instance for an entity, or nil if none exists.
]]
function GameObjectSyncService:GetInstanceForEntity(entity: any): Model?
	return self.EntityToInstance[entity]
end

--[[
    Delete entity and clean up GameObject.
    Should be called BEFORE deleting the entity from JECS world.
]]
function GameObjectSyncService:DeleteEntity(entity: any)
	local instance = self.EntityToInstance[entity]

	if instance then
		-- Destroy GameObject
		self.GameObjectFactory:DestroyWorkerModel(instance)

		-- Clear mappings
		self.EntityToInstance[entity] = nil
		self.InstanceToEntity[instance] = nil
	end

	-- Remove GameObject component if exists
	if self.World:get(entity, self.Components.GameObjectComponent) then
		self.World:remove(entity, self.Components.GameObjectComponent)
	end

	-- Clear equipped state tracking
	self._equippedState[entity] = nil
end

return GameObjectSyncService
