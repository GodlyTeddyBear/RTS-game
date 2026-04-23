--!strict

local RUN_SPEED_THRESHOLD = 17

local EnemyGameObjectSyncService = {}
EnemyGameObjectSyncService.__index = EnemyGameObjectSyncService

local function _SetAttributeIfChanged(model: Model, attributeName: string, value: any)
	if model:GetAttribute(attributeName) == value then
		return
	end

	model:SetAttribute(attributeName, value)
end

local function _ComputeAnimationState(pathState: any, role: any): string
	if not pathState or pathState.isMoving ~= true then
		return "Idle"
	end

	if role and type(role.moveSpeed) == "number" and role.moveSpeed >= RUN_SPEED_THRESHOLD then
		return "Run"
	end

	return "Walk"
end

function EnemyGameObjectSyncService.new()
	local self = setmetatable({}, EnemyGameObjectSyncService)
	self.EntityToInstance = {} :: { [any]: Model }
	self.InstanceToEntity = {} :: { [Model]: any }
	return self
end

function EnemyGameObjectSyncService:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("EnemyComponentRegistry"):GetComponents()
	self.EnemyEntityFactory = registry:Get("EnemyEntityFactory")
	self.EnemyModelFactory = registry:Get("EnemyModelFactory")
end

function EnemyGameObjectSyncService:PollPositions()
	for entity, model in pairs(self.EntityToInstance) do
		if model and model.Parent ~= nil then
			local success, err = pcall(function()
				self.EnemyEntityFactory:UpdatePosition(entity, model:GetPivot())
			end)
			if not success then
				warn("[EnemyGameObjectSync] Failed to poll position:", entity, "-", err)
			end
		end
	end
end

function EnemyGameObjectSyncService:SyncDirtyEntities()
	for entity in self.World:query(self.Components.DirtyTag) do
		local success, err = pcall(function()
			self:_SyncEntity(entity)
		end)

		if not success then
			warn("[EnemyGameObjectSync] Failed to sync entity:", entity, "-", err)
		end

		self.World:remove(entity, self.Components.DirtyTag)
	end
end

function EnemyGameObjectSyncService:RegisterEntity(entity: any)
	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if not modelRef or not modelRef.model then
		return
	end

	local model = modelRef.model
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity
end

function EnemyGameObjectSyncService:_ResolveModel(entity: any): Model?
	local model = self.EntityToInstance[entity]
	if model then
		return model
	end

	local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
	if not modelRef or not modelRef.model then
		return nil
	end

	model = modelRef.model
	self.EntityToInstance[entity] = model
	self.InstanceToEntity[model] = entity
	return model
end

function EnemyGameObjectSyncService:_SyncEntity(entity: any)
	local model = self:_ResolveModel(entity)
	if not model then
		return
	end

	local identity = self.EnemyEntityFactory:GetIdentity(entity)
	local health = self.EnemyEntityFactory:GetHealth(entity)
	local role = self.EnemyEntityFactory:GetRole(entity)
	local pathState = self.EnemyEntityFactory:GetPathState(entity)

	if identity then
		model:SetAttribute("EnemyId", identity.enemyId)
		model:SetAttribute("EnemyRole", identity.role)
		model:SetAttribute("WaveNumber", identity.waveNumber)
	end

	if health then
		model:SetAttribute("Health", health.current)
		model:SetAttribute("MaxHealth", health.max)
	end

	if role then
		model:SetAttribute("MoveSpeed", role.moveSpeed)
		model:SetAttribute("Damage", role.damage)
		model:SetAttribute("TargetPreference", role.targetPreference)
	end

	local nextAnimationState = _ComputeAnimationState(pathState, role)
	_SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	_SetAttributeIfChanged(model, "AnimationLooping", true)

	model:SetAttribute("Alive", self.World:has(entity, self.Components.AliveTag))
	model:SetAttribute("GoalReached", self.World:has(entity, self.Components.GoalReachedTag))
end

function EnemyGameObjectSyncService:GetInstanceForEntity(entity: any): Model?
	return self.EntityToInstance[entity]
end

function EnemyGameObjectSyncService:DeleteEntity(entity: any)
	local instance = self.EntityToInstance[entity]
	if instance then
		self.EnemyModelFactory:DestroyModel(instance)
		self.EntityToInstance[entity] = nil
		self.InstanceToEntity[instance] = nil
	end

	if self.World:get(entity, self.Components.ModelRefComponent) then
		self.World:remove(entity, self.Components.ModelRefComponent)
	end
end

function EnemyGameObjectSyncService:CleanupAll()
	for entity in pairs(self.EntityToInstance) do
		self:DeleteEntity(entity)
	end
end

return EnemyGameObjectSyncService
