--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)

local StructureGameObjectSyncService = {}
StructureGameObjectSyncService.__index = StructureGameObjectSyncService
setmetatable(StructureGameObjectSyncService, { __index = BaseGameObjectSyncService })

local ACTIVE_STRUCTURE_ATTACK_ACTION_ID = "Structure.Attack"
local STRUCTURE_ATTACK_ANIMATION_STATE = "StructureAttack"

local function _ComputeAnimationState(combatAction: any): string
	if
		combatAction ~= nil
		and combatAction.CurrentActionId == ACTIVE_STRUCTURE_ATTACK_ACTION_ID
		and (combatAction.ActionState == "Running" or combatAction.ActionState == "Committed")
	then
		return STRUCTURE_ATTACK_ANIMATION_STATE
	end

	return "Idle"
end

-- Sync reads live action state from CombatContext because combat runtime ownership
-- lives there, while StructureContext still owns structure ECS state like health,
-- identity, and structure-side target data.
local function _ResolveCombatRuntimeAction(self: any, entity: number): any?
	local actorHandle = self._combatAdapterService:GetActorHandle(entity)
	local actionStateResult = self._combatContext:GetCombatActorActionState(actorHandle)
	if not actionStateResult.success then
		return nil
	end

	return actionStateResult.value
end

local function _ResolveRuntimeTargetEnemyEntity(combatAction: any): number?
	if type(combatAction) ~= "table" then
		return nil
	end

	local actionData = combatAction.ActionData
	if type(actionData) ~= "table" or type(actionData.TargetEnemyEntity) ~= "number" then
		return nil
	end

	return actionData.TargetEnemyEntity
end

function StructureGameObjectSyncService.new()
	local self = setmetatable(BaseGameObjectSyncService.new("Structure"), StructureGameObjectSyncService)
	self._registry = nil
	self._combatContext = nil
	self._combatAdapterService = nil
	self._enemyEntityFactory = nil
	return self
end

function StructureGameObjectSyncService:_GetComponentRegistryName(): string
	return "StructureComponentRegistry"
end

function StructureGameObjectSyncService:_OnInit(registry: any, _name: string)
	self._registry = registry
end

function StructureGameObjectSyncService:Start()
	local registry = self._registry
	if registry == nil then
		return
	end

	self._combatContext = registry:Get("CombatContext")
	self._combatAdapterService = registry:Get("StructureCombatAdapterService")

	local enemyContext = registry:Get("EnemyContext")
	local enemyEntityFactoryResult = enemyContext:GetEntityFactory()
	if enemyEntityFactoryResult.success then
		self._enemyEntityFactory = enemyEntityFactoryResult.value
	end
end

function StructureGameObjectSyncService:_GetEntityFactoryName(): string
	return "StructureEntityFactory"
end

function StructureGameObjectSyncService:_ComputeAnimationState(combatAction: any): string
	return _ComputeAnimationState(combatAction)
end

function StructureGameObjectSyncService:_GetInstanceFactoryName(): string?
	return "StructureInstanceFactory"
end

function StructureGameObjectSyncService:_QueryAllEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryActiveEntities()
end

-- Sync should read each field from its true owner: structure identity and health come
-- from StructureEntityFactory, while live running combat action comes from CombatContext.
-- This mixed read is intentional and not a layering mistake.
function StructureGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local factory = self:GetEntityFactoryOrThrow()
	local identity = factory:GetIdentity(entity)
	local health = factory:GetHealth(entity)
	local combatAction = _ResolveCombatRuntimeAction(self, entity) or factory:GetCombatAction(entity)
	local targetEnemyEntity = _ResolveRuntimeTargetEnemyEntity(combatAction) or factory:GetTarget(entity)

	if identity ~= nil then
		self:SetAttributeIfChanged(model, "StructureId", identity.StructureId)
		self:SetAttributeIfChanged(model, "StructureType", identity.StructureType)
	end

	if health ~= nil then
		self:SetAttributeIfChanged(model, "Health", health.Current)
		self:SetAttributeIfChanged(model, "MaxHealth", health.Max)
	end

	local nextAnimationState = self:_ComputeAnimationState(combatAction)
	self:SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	self:SetAttributeIfChanged(model, "AnimationLooping", nextAnimationState ~= STRUCTURE_ATTACK_ANIMATION_STATE)
	self:SetAttributeIfChanged(model, "TargetEnemyId", self:_ResolveTargetEnemyId(targetEnemyEntity))
end

function StructureGameObjectSyncService:_ResolveTargetEnemyId(targetEnemyEntity: number?): string?
	if type(targetEnemyEntity) ~= "number" or self._enemyEntityFactory == nil then
		return nil
	end

	local identity = self._enemyEntityFactory:GetIdentity(targetEnemyEntity)
	if identity == nil or type(identity.EnemyId) ~= "string" or identity.EnemyId == "" then
		return nil
	end

	return identity.EnemyId
end

return StructureGameObjectSyncService
