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
	return setmetatable(BaseGameObjectSyncService.new("Structure"), StructureGameObjectSyncService)
end

function StructureGameObjectSyncService:_GetComponentRegistryName(): string
	return "StructureComponentRegistry"
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
end

return StructureGameObjectSyncService
