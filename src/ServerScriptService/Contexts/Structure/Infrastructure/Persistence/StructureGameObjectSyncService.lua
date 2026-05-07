--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)
local StructureConfig = require(ReplicatedStorage.Contexts.Structure.Config.StructureConfig)
local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local StructureRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.StructureRuntimeProfiles)

type TStructureConfig = StructureTypes.TStructureConfig

local StructureGameObjectSyncService = {}
StructureGameObjectSyncService.__index = StructureGameObjectSyncService
setmetatable(StructureGameObjectSyncService, { __index = BaseGameObjectSyncService })

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

local function _ResolveMiningRuntimeAction(self: any, entity: number): any?
	if self._miningContext == nil or self._miningAdapterService == nil then
		return nil
	end

	local actorHandle = self._miningAdapterService:GetActorHandle(entity)
	local actionStateResult = self._miningContext:GetMiningActorActionState(actorHandle)
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
	self._miningContext = nil
	self._miningAdapterService = nil
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
	self._miningContext = registry:Get("MiningContext")
	self._miningAdapterService = registry:Get("StructureMiningAdapterService")

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

-- Sync should read each field from its true owner: structure identity and health come
-- from StructureEntityFactory, while live running combat action comes from CombatContext.
-- This mixed read is intentional and not a layering mistake.
function StructureGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local factory = self:GetEntityFactoryOrThrow()
	local identity = factory:GetIdentity(entity)
	local health = factory:GetHealth(entity)

	if identity ~= nil then
		self:SetAttributeIfChanged(model, "StructureId", identity.StructureId)
		self:SetAttributeIfChanged(model, "StructureType", identity.StructureType)
	end

	if health ~= nil then
		self:SetAttributeIfChanged(model, "Health", health.Current)
		self:SetAttributeIfChanged(model, "MaxHealth", health.Max)
	end

	local structureType = if identity ~= nil then identity.StructureType else nil
	local runtimeProfileId = nil :: string?
	if structureType ~= nil then
		local structureConfig = StructureConfig.STRUCTURES[structureType] :: TStructureConfig?
		if structureConfig ~= nil then
			runtimeProfileId = structureConfig.RuntimeProfileId
		end
	end

	local combatAction = nil
	if runtimeProfileId == "Extract" then
		combatAction = _ResolveMiningRuntimeAction(self, entity) or factory:GetCombatAction(entity)
	elseif runtimeProfileId == "Passive" then
		combatAction = factory:GetCombatAction(entity)
	else
		combatAction = _ResolveCombatRuntimeAction(self, entity) or factory:GetCombatAction(entity)
	end

	local targetEnemyEntity = nil
	if runtimeProfileId ~= "Passive" then
		targetEnemyEntity = _ResolveRuntimeTargetEnemyEntity(combatAction) or factory:GetTarget(entity)
	end

	local nextAnimationState, isAnimationLooping = StructureRuntimeProfiles.ResolveAnimationState({
		VariantId = runtimeProfileId,
		StructureType = structureType,
		CombatAction = combatAction,
	})
	self:SetAttributeIfChanged(model, "AnimationState", nextAnimationState)
	self:SetAttributeIfChanged(model, "AnimationLooping", isAnimationLooping)
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
