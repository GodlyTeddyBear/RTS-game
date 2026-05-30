--!strict

local CombatDamageSystem = {}
CombatDamageSystem.__index = CombatDamageSystem

function CombatDamageSystem.new(entityFactory: any)
	local self = setmetatable({}, CombatDamageSystem)
	self._entityFactory = entityFactory
	return self
end

function CombatDamageSystem:Run()
	-- READS: Combat.DamageRequest [AUTHORITATIVE], Combat.RequestTag, Entity.Health [AUTHORITATIVE]
	-- WRITES: Entity.Health [AUTHORITATIVE], Entity.DirtyTag, Combat.ProcessedTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "DamageRequest", "RequestTag" },
	})
	if not queryResult.success then
		return
	end

	for _, requestEntity in ipairs(queryResult.value) do
		self:_ResolveDamageRequest(requestEntity)
	end
end

function CombatDamageSystem:_ResolveDamageRequest(requestEntity: number)
	local request = self:_Get(requestEntity, "DamageRequest", "Combat")
	if type(request) ~= "table" then
		self:_MarkProcessed(requestEntity)
		return
	end

	local victimEntity = request.VictimEntity
	local amount = request.Amount
	if type(victimEntity) ~= "number" or type(amount) ~= "number" or amount <= 0 then
		self:_MarkProcessed(requestEntity)
		return
	end
	if not self._entityFactory:Exists(victimEntity) then
		self:_MarkProcessed(requestEntity)
		return
	end

	local health = self:_Get(victimEntity, "Health", "Entity")
	if type(health) ~= "table" or type(health.Current) ~= "number" then
		self:_MarkProcessed(requestEntity)
		return
	end

	local maxHealth = if type(health.Max) == "number" then health.Max else health.Current
	self._entityFactory:Set(victimEntity, "Health", {
		Current = math.max(0, health.Current - amount),
		Max = maxHealth,
	}, "Entity")
	self._entityFactory:Add(victimEntity, "DirtyTag", "Entity")
	self:_MarkProcessed(requestEntity)
end

function CombatDamageSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function CombatDamageSystem:_MarkProcessed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return CombatDamageSystem
