--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local UnitEntityReadService = {}
UnitEntityReadService.__index = UnitEntityReadService

function UnitEntityReadService.new(entityContext: any?)
	local self = setmetatable({}, UnitEntityReadService)
	self._entityContext = entityContext
	return self
end

function UnitEntityReadService:Configure(entityContext: any)
	self._entityContext = entityContext
end

function UnitEntityReadService:Start(registry: any, _name: string)
	if self._entityContext == nil then
		self._entityContext = registry:Get("EntityContext")
	end
end

function UnitEntityReadService:QueryActiveEntities(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Unit",
		Keys = {
			{ Key = "ActiveTag", FeatureName = "Entity" },
			{ Key = "Role", FeatureName = "Unit" },
		},
	})
	return if queryResult.success then queryResult.value else {}
end

function UnitEntityReadService:QueryOwnerEntities(ownerKind: string, ownerId: string): { number }
	local entities = {}
	for _, entity in ipairs(self:QueryActiveEntities()) do
		local ownership = self:GetOwnership(entity)
		if type(ownership) == "table" and ownership.OwnerKind == ownerKind and ownership.OwnerId == ownerId then
			table.insert(entities, entity)
		end
	end
	return entities
end

function UnitEntityReadService:GetOwnerUnitCount(ownerKind: string, ownerId: string): number
	return #self:QueryOwnerEntities(ownerKind, ownerId)
end

function UnitEntityReadService:GetEntityByUnitGuid(unitGuid: string): number?
	if type(unitGuid) ~= "string" or unitGuid == "" then
		return nil
	end
	for _, entity in ipairs(self:QueryActiveEntities()) do
		local identity = self:GetIdentity(entity)
		if type(identity) == "table" and identity.EntityId == unitGuid then
			return entity
		end
	end
	return nil
end

function UnitEntityReadService:IsActive(entity: number?): boolean
	if type(entity) ~= "number" then
		return false
	end
	local result = self._entityContext:Has(entity, "ActiveTag", "Entity")
	return result.success and result.value == true
end

function UnitEntityReadService:GetIdentity(entity: number): any?
	local identityResult = self._entityContext:Get(entity, "Identity", "Entity")
	local identity = if identityResult.success then identityResult.value else nil
	if type(identity) ~= "table" then
		return nil
	end
	return {
		UnitGuid = identity.EntityId,
		UnitId = identity.DefinitionId,
	}
end

function UnitEntityReadService:GetOwnership(entity: number): any?
	local result = self._entityContext:Get(entity, "Ownership", "Entity")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetHealth(entity: number): any?
	local result = self._entityContext:Get(entity, "Health", "Entity")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetRole(entity: number): any?
	local result = self._entityContext:Get(entity, "Role", "Unit")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetPathState(entity: number): any?
	local result = self._entityContext:Get(entity, "PathState", "Unit")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetBuilderAssignment(entity: number): any?
	local result = self._entityContext:Get(entity, "BuilderAssignment", "Unit")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetCurrentMoveSpeed(entity: number): number?
	local result = self._entityContext:Get(entity, "CurrentMoveSpeed", "Unit")
	local moveSpeed = if result.success then result.value else nil
	return if type(moveSpeed) == "table" and type(moveSpeed.Value) == "number" then moveSpeed.Value else nil
end

function UnitEntityReadService:GetPosition(entity: number): any?
	local result = self._entityContext:Get(entity, "Transform", "Entity")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetEntityCFrame(entity: number): CFrame?
	local transform = self:GetPosition(entity)
	return if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then transform.CFrame else nil
end

function UnitEntityReadService:GetModelRef(entity: number): any?
	local result = self._entityContext:Get(entity, "ModelRef", "Entity")
	return if result.success then result.value else nil
end

function UnitEntityReadService:GetNearestOwnedUnit(ownerKind: string, ownerId: string, position: Vector3, maxRange: number): number?
	return SpatialQuery.FindBestCandidate(position, self:QueryOwnerEntities(ownerKind, ownerId), function(entity: number): Vector3?
		local cframe = self:GetEntityCFrame(entity)
		return if cframe ~= nil then cframe.Position else nil
	end, function(_entity: number, distance: number): number?
		return -distance
	end, maxRange)
end

return UnitEntityReadService
