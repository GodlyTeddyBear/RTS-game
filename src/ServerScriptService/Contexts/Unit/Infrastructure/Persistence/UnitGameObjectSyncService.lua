--!strict

--[=[
    @class UnitGameObjectSyncService
    Syncs authoritative unit ECS state into the live unit model instances on the server.

    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseGameObjectSyncService = require(ServerStorage.Utilities.ECSUtilities.BaseGameObjectSyncService)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)

local UnitGameObjectSyncService = {}
UnitGameObjectSyncService.__index = UnitGameObjectSyncService
setmetatable(UnitGameObjectSyncService, { __index = BaseGameObjectSyncService })

-- Creates the sync service bound to the Unit namespace.
function UnitGameObjectSyncService.new()
	return setmetatable(BaseGameObjectSyncService.new("Unit"), UnitGameObjectSyncService)
end

-- Tells the base sync service which registry stores the unit components.
function UnitGameObjectSyncService:_GetComponentRegistryName(): string
	return "UnitComponentRegistry"
end

-- Tells the base sync service which entity factory owns unit entities.
function UnitGameObjectSyncService:_GetEntityFactoryName(): string
	return "UnitEntityFactory"
end

-- Tells the base sync service which instance factory provides unit models.
function UnitGameObjectSyncService:_GetInstanceFactoryName(): string?
	return "UnitInstanceFactory"
end

-- Polls all active units for sync because unit models are authoritative gameplay objects.
function UnitGameObjectSyncService:_QueryAllEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryActiveEntities()
end

-- Polls the same active unit set during the poll phase so transforms and attributes stay current.
function UnitGameObjectSyncService:_QueryPollEntities(): { number }
	return self:GetEntityFactoryOrThrow():QueryActiveEntities()
end

-- Returns the dirty tag that marks which units need a sync pass.
function UnitGameObjectSyncService:_GetDirtyTag(): any?
	return self:GetComponentsOrThrow().DirtyTag
end

-- Clears the dirty tag after a unit has been synchronized to its model.
function UnitGameObjectSyncService:_ClearDirty(entity: number)
	local world = self:GetWorldOrThrow()
	local components = self:GetComponentsOrThrow()
	if world:has(entity, components.DirtyTag) then
		world:remove(entity, components.DirtyTag)
	end
end

-- Copies authoritative ECS state onto the live unit model attributes and transform.
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
		self:SetAttributeIfChanged(model, "UnitRole", role.Role)
		self:SetAttributeIfChanged(model, "UnitDisplayName", role.DisplayName)
	end

	if ownership ~= nil then
		self:SetAttributeIfChanged(model, "Faction", ownership.Faction)
		self:SetAttributeIfChanged(model, "OwnerKind", ownership.OwnerKind)
		self:SetAttributeIfChanged(model, "OwnerId", ownership.OwnerId)
	end

	self:SetAttributeIfChanged(model, "Active", entityFactory:IsActive(entity))
	self:SetAttributeIfChanged(model, "AnimationState", entityFactory:GetAnimationState(entity))
	self:SetAttributeIfChanged(model, "AnimationLooping", entityFactory:GetAnimationLooping(entity))
end

-- Polls the model transform back into the entity so direct model movement remains authoritative.
function UnitGameObjectSyncService:_PollEntity(entity: number, model: Model)
	self:GetEntityFactoryOrThrow():SetTransform(entity, ModelPlus.GetPivot(model))
end

return UnitGameObjectSyncService
