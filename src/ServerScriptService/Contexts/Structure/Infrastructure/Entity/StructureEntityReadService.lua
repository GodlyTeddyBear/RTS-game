--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local StructureEntityReadService = {}
StructureEntityReadService.__index = StructureEntityReadService

function StructureEntityReadService.new()
	local self = setmetatable({}, StructureEntityReadService)
	return self
end

function StructureEntityReadService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "StructureEntityReadService missing EntityContext in Start")
end

function StructureEntityReadService:QueryPlacedEntities(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Structure",
		Keys = { "PlacedTag" },
	})
	return if queryResult.success then queryResult.value else {}
end

function StructureEntityReadService:QueryOperationalEntities(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Structure",
		Keys = { "OperationalTag" },
	})
	return if queryResult.success then queryResult.value else {}
end

function StructureEntityReadService:QueryOwnedUnderConstructionEntities(ownerUserId: number): { number }
	local entities = {}
	for _, entity in ipairs(self:QueryPlacedEntities()) do
		if self:IsUnderConstruction(entity) and self:IsOwnedByUser(entity, ownerUserId) then
			table.insert(entities, entity)
		end
	end
	return entities
end

function StructureEntityReadService:IsPlaced(entity: number?): boolean
	if type(entity) ~= "number" then
		return false
	end
	local result = self._entityContext:Has(entity, "PlacedTag", "Structure")
	return result.success and result.value == true
end

function StructureEntityReadService:IsOperational(entity: number?): boolean
	if type(entity) ~= "number" then
		return false
	end
	local result = self._entityContext:Has(entity, "OperationalTag", "Structure")
	return result.success and result.value == true
end

function StructureEntityReadService:IsUnderConstruction(entity: number?): boolean
	if type(entity) ~= "number" then
		return false
	end
	local result = self._entityContext:Has(entity, "UnderConstructionTag", "Structure")
	return result.success and result.value == true
end

function StructureEntityReadService:IsOwnedByUser(entity: number?, ownerUserId: number): boolean
	if type(entity) ~= "number" then
		return false
	end
	local sourcePlacement = self:GetSourcePlacement(entity)
	return type(sourcePlacement) == "table" and sourcePlacement.OwnerUserId == ownerUserId
end

function StructureEntityReadService:GetIdentity(entity: number): any?
	local identityResult = self._entityContext:Get(entity, "Identity", "Entity")
	return if identityResult.success then identityResult.value else nil
end

function StructureEntityReadService:GetHealth(entity: number): any?
	local healthResult = self._entityContext:Get(entity, "Health", "Entity")
	return if healthResult.success then healthResult.value else nil
end

function StructureEntityReadService:GetStats(entity: number): any?
	local statsResult = self._entityContext:Get(entity, "Stats", "Structure")
	return if statsResult.success then statsResult.value else nil
end

function StructureEntityReadService:GetConstruction(entity: number): any?
	local constructionResult = self._entityContext:Get(entity, "Construction", "Structure")
	return if constructionResult.success then constructionResult.value else nil
end

function StructureEntityReadService:GetSourcePlacement(entity: number): any?
	local placementResult = self._entityContext:Get(entity, "SourcePlacement", "Structure")
	return if placementResult.success then placementResult.value else nil
end

function StructureEntityReadService:GetTarget(entity: number): number?
	local targetResult = self._entityContext:Get(entity, "Target", "Entity")
	local target = if targetResult.success then targetResult.value else nil
	if type(target) ~= "table" then
		return nil
	end
	return if type(target.TargetEntity) == "number" then target.TargetEntity else nil
end

function StructureEntityReadService:GetPosition(entity: number): Vector3?
	local transformResult = self._entityContext:Get(entity, "Transform", "Entity")
	local transform = if transformResult.success then transformResult.value else nil
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		return transform.CFrame.Position
	end
	local sourcePlacement = self:GetSourcePlacement(entity)
	return if type(sourcePlacement) == "table" and typeof(sourcePlacement.WorldPos) == "Vector3"
		then sourcePlacement.WorldPos
		else nil
end

function StructureEntityReadService:GetEntityCFrame(entity: number): CFrame?
	local transformResult = self._entityContext:Get(entity, "Transform", "Entity")
	local transform = if transformResult.success then transformResult.value else nil
	return if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then transform.CFrame else nil
end

function StructureEntityReadService:GetConstructionPercent(entity: number): number
	local construction = self:GetConstruction(entity)
	if type(construction) ~= "table" or type(construction.RequiredWork) ~= "number" or construction.RequiredWork <= 0 then
		return 0
	end
	return math.clamp(((construction.CurrentWork or 0) / construction.RequiredWork) * 100, 0, 100)
end

function StructureEntityReadService:GetEntityByStructureId(structureId: string): number?
	if type(structureId) ~= "string" or structureId == "" then
		return nil
	end
	for _, entity in ipairs(self:QueryPlacedEntities()) do
		local identity = self:GetIdentity(entity)
		if type(identity) == "table" and identity.EntityId == structureId then
			return entity
		end
	end
	return nil
end

function StructureEntityReadService:FindNearestOwnedUnfinishedStructure(
	ownerUserId: number,
	position: Vector3,
	maxRange: number
): number?
	local candidates = self:QueryOwnedUnderConstructionEntities(ownerUserId)
	return SpatialQuery.FindBestCandidate(position, candidates, function(entity: number): Vector3?
		return self:GetPosition(entity)
	end, function(_entity: number, distance: number): number?
		return -distance
	end, maxRange)
end

return StructureEntityReadService
