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
	-- WRITES: Combat.HealthDepletedOutcomeRequest, Combat.ProcessedTag
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

	local outcome = if type(request.VictimEntity) == "number"
		then self:_Get(request.VictimEntity, "HealthDepletedOutcome", "Entity")
		else nil
	local outcomeId = if type(outcome) == "table" and type(outcome.OutcomeId) == "string"
		then outcome.OutcomeId
		else request.VictimKind
	local rule = self._ruleRegistry:GetHealthDepletedRule(outcomeId)
	if type(rule) ~= "table" then
		self:_Processed(requestEntity)
		return
	end

	self:_CreateOutcomeRequest(rule, request)

	self:_Processed(requestEntity)
end

function HealthDepletedOutcomeSystem:_CreateOutcomeRequest(rule: any, request: any)
	if type(request.VictimEntity) ~= "number" then
		return
	end

	local outcomeId = rule.OutcomeId
	if type(outcomeId) ~= "string" or outcomeId == "" then
		return
	end

	local now = os.clock()
	self._entityFactory:CreateFromArchetype("Combat.HealthDepletedOutcomeRequest", {
		HealthDepletedOutcomeRequest = {
			VictimEntity = request.VictimEntity,
			VictimKind = request.VictimKind,
			OutcomeId = outcomeId,
			CreatedAt = now,
			ExpiresAt = now + 1,
		},
	})
end

function HealthDepletedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function HealthDepletedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

return HealthDepletedOutcomeSystem
