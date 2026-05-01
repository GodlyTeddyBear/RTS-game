--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)
local UnitConfig = require(ReplicatedStorage.Contexts.Unit.Config.UnitConfig)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local UnitRuntimeProfiles = require(script.Parent.Parent.Runtime.Profiles.UnitRuntimeProfiles)

type UnitDefinition = UnitTypes.UnitDefinition

local UnitGameObjectSyncService = {}
UnitGameObjectSyncService.__index = UnitGameObjectSyncService
setmetatable(UnitGameObjectSyncService, { __index = BaseGameObjectSyncService })

function UnitGameObjectSyncService.new()
	return setmetatable(BaseGameObjectSyncService.new("Unit"), UnitGameObjectSyncService)
end

function UnitGameObjectSyncService:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

function UnitGameObjectSyncService:_GetEntityFactoryName(): string
	return "UnitEntityFactory"
end

function UnitGameObjectSyncService:_GetInstanceFactoryName(): string?
	return "UnitInstanceFactory"
end

function UnitGameObjectSyncService:_QueryAllEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryActiveEntities()
end

function UnitGameObjectSyncService:_GetDirtyTag(): any?
	return self:GetComponentsOrThrow().DirtyTag
end

function UnitGameObjectSyncService:_ClearDirty(entity: number)
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	if world:has(entity, components.DirtyTag) then
		world:remove(entity, components.DirtyTag)
	end
end

function UnitGameObjectSyncService:_SyncEntity(entity: number, model: Model)
	local entityFactory = self:GetEntityFactoryOrThrow()
	local identity = entityFactory:GetIdentity(entity)
	local transform = entityFactory:GetTransform(entity)
	local health = entityFactory:GetHealth(entity)
	local role = entityFactory:GetRole(entity)
	local ownership = entityFactory:GetOwnership(entity)

	if transform ~= nil then
		ModelPlus.MoveToCFrame(model, transform.CFrame)
	end

	if health ~= nil then
		self:SetAttributeIfChanged(model, "Health", health.Hp)
		self:SetAttributeIfChanged(model, "MaxHealth", health.MaxHp)
	end

	if role ~= nil then
		self:SetAttributeIfChanged(model, "UnitDisplayName", role.DisplayName)
	end

	if ownership ~= nil then
		self:SetAttributeIfChanged(model, "Faction", ownership.Faction)
		self:SetAttributeIfChanged(model, "OwnerKind", ownership.OwnerKind)
		self:SetAttributeIfChanged(model, "OwnerId", ownership.OwnerId)
	end

	self:SetAttributeIfChanged(model, "Active", entityFactory:IsActive(entity))
	local runtimeProfileId = "Idle"
	if identity ~= nil then
		local definition = UnitConfig.Definitions[identity.UnitId] :: UnitDefinition?
		if definition ~= nil and type(definition.RuntimeProfileId) == "string" and definition.RuntimeProfileId ~= "" then
			runtimeProfileId = definition.RuntimeProfileId
		end
	end

	local animationState, isLooping = UnitRuntimeProfiles.ResolveAnimationState({
		VariantId = runtimeProfileId,
		CombatAction = nil,
	})
	self:SetAttributeIfChanged(model, "AnimationState", animationState)
	self:SetAttributeIfChanged(model, "AnimationLooping", isLooping)
end

return UnitGameObjectSyncService
