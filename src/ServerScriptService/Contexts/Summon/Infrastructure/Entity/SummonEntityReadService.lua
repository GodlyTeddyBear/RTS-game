--!strict

local SummonEntityReadService = {}
SummonEntityReadService.__index = SummonEntityReadService

function SummonEntityReadService.new(entityContext: any?)
	local self = setmetatable({}, SummonEntityReadService)
	self._entityContext = entityContext
	return self
end

function SummonEntityReadService:Start(registry: any, _name: string)
	if self._entityContext == nil then
		self._entityContext = registry:Get("EntityContext")
	end
end

function SummonEntityReadService:QueryActiveDrones(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Summon",
		Keys = {
			{ Key = "ActiveTag", FeatureName = "Entity" },
			{ Key = "DroneTag", FeatureName = "Summon" },
		},
	})
	return if queryResult.success then queryResult.value else {}
end

function SummonEntityReadService:QueryOwnerDrones(ownerUserId: number): { number }
	local ownerId = tostring(ownerUserId)
	local entities = {}
	for _, entity in ipairs(self:QueryActiveDrones()) do
		local ownership = self:GetOwnership(entity)
		if type(ownership) == "table" and ownership.OwnerKind == "Player" and ownership.OwnerId == ownerId then
			table.insert(entities, entity)
		end
	end
	return entities
end

function SummonEntityReadService:GetOwnerDroneCount(ownerUserId: number): number
	return #self:QueryOwnerDrones(ownerUserId)
end

function SummonEntityReadService:GetIdentity(entity: number): any?
	local result = self._entityContext:Get(entity, "Identity", "Entity")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetOwnership(entity: number): any?
	local result = self._entityContext:Get(entity, "Ownership", "Entity")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetTransform(entity: number): any?
	local result = self._entityContext:Get(entity, "Transform", "Entity")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetCFrame(entity: number): CFrame?
	local transform = self:GetTransform(entity)
	return if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then transform.CFrame else nil
end

function SummonEntityReadService:GetCombatProfile(entity: number): any?
	local result = self._entityContext:Get(entity, "CombatProfile", "Summon")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetAttackCooldown(entity: number): any?
	local result = self._entityContext:Get(entity, "AttackCooldown", "Summon")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetLifetime(entity: number): any?
	local result = self._entityContext:Get(entity, "Lifetime", "Entity")
	return if result.success then result.value else nil
end

function SummonEntityReadService:GetBoundPart(entity: number): BasePart?
	local boundResult = self._entityContext:GetBoundInstance(entity)
	local boundInstance = if boundResult.success then boundResult.value else nil
	return if boundInstance ~= nil and boundInstance:IsA("BasePart") then boundInstance else nil
end

return SummonEntityReadService
