--!strict

local HealthDepletedOutcomeSystem = {}
HealthDepletedOutcomeSystem.__index = HealthDepletedOutcomeSystem

function HealthDepletedOutcomeSystem.new(entityFactory: any, dependencies: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_entityContext = dependencies.EntityContext,
		_ruleRegistry = dependencies.RuleRegistry,
	}, HealthDepletedOutcomeSystem)
end

function HealthDepletedOutcomeSystem:Run()
	-- READS: Combat.HealthDepletedRequest [AUTHORITATIVE]
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function HealthDepletedOutcomeSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthDepletedRequest", "Combat")
	if type(request) ~= "table" or type(request.VictimKind) ~= "string" then
		self:_Processed(requestEntity)
		return
	end

	local rule = self._ruleRegistry:GetHealthDepletedRule(request.VictimKind)
	if type(rule) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	if type(rule.OnDepleted) == "function" then
		rule.OnDepleted({
			Request = request,
			EntityFactory = self._entityFactory,
			EntityContext = self._entityContext,
		})
	end
	if rule.MarkVictimForDestruction == true and type(request.VictimEntity) == "number" then
		self._entityContext:MarkForDestruction(request.VictimEntity)
	end

	self:_Processed(requestEntity)
end

function HealthDepletedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function HealthDepletedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return HealthDepletedOutcomeSystem
