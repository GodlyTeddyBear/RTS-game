--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseGameObjectSyncService = require(ReplicatedStorage.Utilities.BaseGameObjectSyncService)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

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
	self:SetAttributeIfChanged(model, "AnimationState", "Idle")
	self:SetAttributeIfChanged(model, "AnimationLooping", true)
end

return UnitGameObjectSyncService
