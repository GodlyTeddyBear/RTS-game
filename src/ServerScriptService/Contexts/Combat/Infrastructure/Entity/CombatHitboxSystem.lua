--!strict

local CombatHitboxSystem = {}
CombatHitboxSystem.__index = CombatHitboxSystem

function CombatHitboxSystem.new(entityFactory: any)
	local self = setmetatable({}, CombatHitboxSystem)
	self._entityFactory = entityFactory
	return self
end

function CombatHitboxSystem:Run()
	-- READS: Combat.HitboxRequest [AUTHORITATIVE], Combat.RequestTag
	-- WRITES: Combat.DamageRequest [AUTHORITATIVE], Combat.ProcessedTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "HitboxRequest", "RequestTag" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, requestEntity in ipairs(queryResult.value) do
		self:_ResolveHitboxRequest(requestEntity, now)
	end
end

function CombatHitboxSystem:_ResolveHitboxRequest(requestEntity: number, now: number)
	local request = self:_Get(requestEntity, "HitboxRequest", "Combat")
	if type(request) ~= "table" then
		self:_MarkProcessed(requestEntity)
		return
	end
	if type(request.TargetEntity) ~= "number" or type(request.Damage) ~= "number" or request.Damage <= 0 then
		self:_MarkProcessed(requestEntity)
		return
	end

	self._entityFactory:CreateFromArchetype("Combat.DamageRequest", {
		DamageRequest = {
			ActionId = request.ActionId,
			AttackerEntity = request.SourceEntity,
			VictimEntity = request.TargetEntity,
			Amount = request.Damage,
			CreatedAt = now,
			Reason = "HitboxRequest",
		},
	})
	self:_MarkProcessed(requestEntity)
end

function CombatHitboxSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function CombatHitboxSystem:_MarkProcessed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return CombatHitboxSystem
