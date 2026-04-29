--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)

local StructureGameObjectSyncService = {}
StructureGameObjectSyncService.__index = StructureGameObjectSyncService
setmetatable(StructureGameObjectSyncService, { __index = BaseGameObjectSyncService })

local function _ComputeAnimationState(combatAction: any): string
	if
		combatAction ~= nil
		and combatAction.CurrentActionId == "StructureAttack"
		and (combatAction.ActionState == "Running" or combatAction.ActionState == "Committed")
	then
		return "StructureAttack"
	end

	return "Idle"
end

function StructureGameObjectSyncService.new()
	local self = setmetatable(BaseGameObjectSyncService.new("Structure"), StructureGameObjectSyncService)
	self._registry = nil
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

	local enemyContext = registry:Get("EnemyContext")
	local enemyEntityFactoryResult = enemyContext:GetEntityFactory()
	if enemyEntityFactoryResult.success then
		self._enemyEntityFactory = enemyEntityFactoryResult.value
	end
end

function StructureGameObjectSyncService:_GetEntityFactoryName(): string
	return "StructureEntityFactory"
end

function StructureGameObjectSyncService:_GetInstanceFactoryName(): string?
	return "StructureInstanceFactory"
end

function StructureGameObjectSyncService:_QueryAllEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryActiveEntities()
end

function StructureGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local factory = self:GetEntityFactoryOrThrow()
	local identity = factory:GetIdentity(entity)
	local health = factory:GetHealth(entity)
	local combatAction = factory:GetCombatAction(entity)
	local targetEnemyEntity = factory:GetTarget(entity)

	if identity ~= nil then
		self:SetAttributeIfChanged(model, "StructureId", identity.StructureId)
		self:SetAttributeIfChanged(model, "StructureType", identity.StructureType)
	end

	if health ~= nil then
		self:SetAttributeIfChanged(model, "Health", health.Current)
		self:SetAttributeIfChanged(model, "MaxHealth", health.Max)
	end

	local nextAnimationState = _ComputeAnimationState(combatAction)
	self:SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	self:SetAttributeIfChanged(model, "AnimationLooping", nextAnimationState ~= "StructureAttack")
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
