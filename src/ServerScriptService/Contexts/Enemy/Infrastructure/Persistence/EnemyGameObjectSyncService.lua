--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)

local RUN_SPEED_THRESHOLD = 17

local EnemyGameObjectSyncService = {}
EnemyGameObjectSyncService.__index = EnemyGameObjectSyncService
setmetatable(EnemyGameObjectSyncService, { __index = BaseGameObjectSyncService })

local function _SetAttributeIfChanged(model: Model, attributeName: string, value: any)
	if model:GetAttribute(attributeName) == value then
		return
	end

	model:SetAttribute(attributeName, value)
end

local function _ComputeAnimationState(pathState: any, role: any, combatAction: any): string
	if
		combatAction ~= nil
		and (combatAction.CurrentActionId == "AttackStructure" or combatAction.CurrentActionId == "AttackBase")
		and (combatAction.ActionState == "Running" or combatAction.ActionState == "Committed")
	then
		return combatAction.CurrentActionId
	end

	if not pathState or pathState.isMoving ~= true then
		return "Idle"
	end

	if role and type(role.moveSpeed) == "number" and role.moveSpeed >= RUN_SPEED_THRESHOLD then
		return "Run"
	end

	return "Walk"
end

function EnemyGameObjectSyncService.new()
	return setmetatable(BaseGameObjectSyncService.new("Enemy"), EnemyGameObjectSyncService)
end

function EnemyGameObjectSyncService:_GetComponentRegistryName(): string
	return "EnemyComponentRegistry"
end

function EnemyGameObjectSyncService:_GetEntityFactoryName(): string
	return "EnemyEntityFactory"
end

function EnemyGameObjectSyncService:_GetInstanceFactoryName(): string?
	return "EnemyInstanceFactory"
end

function EnemyGameObjectSyncService:_QueryPollEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryAliveEntities()
end

function EnemyGameObjectSyncService:_GetDirtyTag(): any?
	return self:GetComponentsOrThrow().DirtyTag
end

function EnemyGameObjectSyncService:_ClearDirty(entity: number)
	self:GetWorldOrThrow():remove(entity, self:GetComponentsOrThrow().DirtyTag)
end

function EnemyGameObjectSyncService:_PollEntity(entity: number, model: Model)
	self:GetEntityFactoryOrThrow():UpdatePosition(entity, model:GetPivot())
end

function EnemyGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local entityFactory = self:GetEntityFactoryOrThrow()
	local components = self:GetComponentsOrThrow()
	local world = self:GetWorldOrThrow()

	local health = entityFactory:GetHealth(entity)
	local role = entityFactory:GetRole(entity)
	local pathState = entityFactory:GetPathState(entity)
	local combatAction = entityFactory:GetCombatAction(entity)

	if health then
		self:SetAttributeIfChanged(model, "Health", health.current)
		self:SetAttributeIfChanged(model, "MaxHealth", health.max)
	end

	if role then
		self:SetAttributeIfChanged(model, "MoveSpeed", role.moveSpeed)
		self:SetAttributeIfChanged(model, "Damage", role.damage)
		self:SetAttributeIfChanged(model, "TargetPreference", role.targetPreference)
	end

	local nextAnimationState = _ComputeAnimationState(pathState, role, combatAction)
	_SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	_SetAttributeIfChanged(model, "AnimationLooping", nextAnimationState ~= "AttackStructure" and nextAnimationState ~= "AttackBase")

	self:SetAttributeIfChanged(model, "Alive", world:has(entity, components.AliveTag))
	self:SetAttributeIfChanged(model, "GoalReached", world:has(entity, components.GoalReachedTag))
end

return EnemyGameObjectSyncService
