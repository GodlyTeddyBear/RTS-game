--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseGameObjectSyncService = require(ServerStorage.Utilities.ECSUtilities.BaseGameObjectSyncService)
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)
local EnemyTypes = require(ReplicatedStorage.Contexts.Enemy.Types.EnemyTypes)
local EnemyRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.EnemyRuntimeProfiles)

type CombatActionState = CombatTypes.CombatActionState
type EnemyRoleConfig = EnemyTypes.EnemyRoleConfig

local EnemyGameObjectSyncService = {}
EnemyGameObjectSyncService.__index = EnemyGameObjectSyncService
setmetatable(EnemyGameObjectSyncService, { __index = BaseGameObjectSyncService })

local function _ResolveCombatRuntimeAction(self: any, entity: number): CombatActionState?
	local actorHandle = self._combatAdapterService:GetActorHandle(entity)
	local actionStateResult = self._combatContext:GetCombatActorActionState(actorHandle)
	if not actionStateResult.success then
		return nil
	end

	return actionStateResult.value
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

function EnemyGameObjectSyncService:Start(registry: any, _name: string)
	self._combatContext = registry:Get("CombatContext")
	self._combatAdapterService = registry:Get("EnemyCombatAdapterService")
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
	self:GetEntityFactoryOrThrow():UpdatePosition(entity, ModelPlus.GetPivot(model))
end

function EnemyGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local entityFactory = self:GetEntityFactoryOrThrow()
	local components = self:GetComponentsOrThrow()
	local world = self:GetWorldOrThrow()

	local health = entityFactory:GetHealth(entity)
	local role = entityFactory:GetRole(entity)
	local baseMoveSpeed = entityFactory:GetBaseMoveSpeed(entity)
	local currentMoveSpeed = entityFactory:GetCurrentMoveSpeed(entity)
	local pathState = entityFactory:GetPathState(entity)
	local combatAction = _ResolveCombatRuntimeAction(self, entity)

	if health then
		self:SetAttributeIfChanged(model, "Health", health.Current)
		self:SetAttributeIfChanged(model, "MaxHealth", health.Max)
	end

	if role then
		self:SetAttributeIfChanged(model, "MoveSpeed", currentMoveSpeed or role.MoveSpeed)
		self:SetAttributeIfChanged(model, "BaseMoveSpeed", baseMoveSpeed or role.MoveSpeed)
		self:SetAttributeIfChanged(model, "CurrentMoveSpeed", currentMoveSpeed or role.MoveSpeed)
		self:SetAttributeIfChanged(model, "Damage", role.Damage)
		self:SetAttributeIfChanged(model, "TargetPreference", role.TargetPreference)
	end

	local roleName = if role ~= nil then role.Role else nil
	local moveSpeed = if currentMoveSpeed ~= nil then currentMoveSpeed else if role ~= nil then role.MoveSpeed else nil
	local isMoving = pathState ~= nil and pathState.IsMoving == true
	local runtimeProfileId = nil :: string?
	if roleName ~= nil then
		local roleConfig = EnemyConfig.Roles[roleName] :: EnemyRoleConfig?
		if roleConfig ~= nil then
			runtimeProfileId = roleConfig.RuntimeProfileId
		end
	end

	local nextAnimationState, isAnimationLooping = EnemyRuntimeProfiles.ResolveAnimationState({
		VariantId = runtimeProfileId,
		RoleName = roleName,
		MoveSpeed = moveSpeed,
		IsMoving = isMoving,
		CombatAction = combatAction,
	})
	self:SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	self:SetAttributeIfChanged(model, "AnimationLooping", isAnimationLooping)

	self:SetAttributeIfChanged(model, "Alive", world:has(entity, components.AliveTag))
	self:SetAttributeIfChanged(model, "GoalReached", world:has(entity, components.GoalReachedTag))
end

return EnemyGameObjectSyncService
