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
	return setmetatable({}, EnemyGameObjectSyncService)
end

function EnemyGameObjectSyncService:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("EnemyComponentRegistry"):GetComponents()
	self.EnemyEntityFactory = registry:Get("EnemyEntityFactory")
	self.EnemyInstanceFactory = registry:Get("EnemyInstanceFactory")
end

function EnemyGameObjectSyncService:PollPositions()
	for _, entity in self.EnemyEntityFactory:QueryAliveEntities() do
		local model = self.EnemyInstanceFactory:GetInstance(entity)
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

function EnemyGameObjectSyncService:RegisterEntity(entity: any, model: Model?)
	local resolvedModel = model
	if resolvedModel == nil then
		local modelRef = self.World:get(entity, self.Components.ModelRefComponent)
		if modelRef and modelRef.model then
			resolvedModel = modelRef.model
		end
	end

	if resolvedModel == nil then
		return
	end

	self:_SyncEntity(entity, resolvedModel)
end

function EnemyGameObjectSyncService:_SyncEntity(entity: any, explicitModel: Model?)
	local model = explicitModel or self.EnemyInstanceFactory:GetInstance(entity)
	if not model then
		return
	end

	local health = self.EnemyEntityFactory:GetHealth(entity)
	local role = self.EnemyEntityFactory:GetRole(entity)
	local pathState = self.EnemyEntityFactory:GetPathState(entity)

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
	return self.EnemyInstanceFactory:GetInstance(entity) :: Model?
end

function EnemyGameObjectSyncService:CleanupAll()
	return
end

return EnemyGameObjectSyncService
