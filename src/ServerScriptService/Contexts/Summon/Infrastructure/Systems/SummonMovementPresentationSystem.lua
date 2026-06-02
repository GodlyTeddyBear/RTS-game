--!strict

local SummonMovementPresentationSystem = {}
SummonMovementPresentationSystem.__index = SummonMovementPresentationSystem

function SummonMovementPresentationSystem.new(entityFactory: any, entityContext: any)
	return setmetatable({ _entityFactory = entityFactory, _entityContext = entityContext }, SummonMovementPresentationSystem)
end

function SummonMovementPresentationSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE]
	-- WRITES: Summon.TargetEnemyId [DERIVED]
	local result = self._entityFactory:Query({ FeatureName = "Summon", Keys = { "DroneTag" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local target = if type(intent) == "table" then intent.TargetEntity else nil
		local identity = if type(target) == "number" then self:_Get(target, "Identity", "Entity") else nil
		self._entityFactory:Set(entity, "TargetEnemyId", if type(identity) == "table" then identity.EntityId else nil, "Summon")
		self._entityFactory:Add(entity, "DirtyTag", "Entity")
	end
end

function SummonMovementPresentationSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return SummonMovementPresentationSystem
