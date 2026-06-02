--!strict

local MovementGoalReachedSystem = {}
MovementGoalReachedSystem.__index = MovementGoalReachedSystem

function MovementGoalReachedSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({ _entityFactory = entityFactory, _ruleRegistry = ruleRegistry }, MovementGoalReachedSystem)
end

function MovementGoalReachedSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
	-- WRITES: configured goal reached tags and request components
	for _, rule in ipairs(self._ruleRegistry:GetGoalReachedRules()) do
		self:_RunRule(rule)
	end
end

function MovementGoalReachedSystem:_RunRule(rule: any)
	local query = rule.Query
	if type(query) ~= "table" then
		return
	end

	local result = self._entityFactory:Query(query)
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local applyResult = self:_Get(entity, "ApplyResult", "Movement")
		if type(intent) == "table"
			and intent.ActionId == rule.ActionId
			and type(applyResult) == "table"
			and applyResult.IsDone == true
		then
			self:_ApplyRule(rule, entity, intent, applyResult)
		end
	end
end

function MovementGoalReachedSystem:_ApplyRule(rule: any, entity: number, intent: any, applyResult: any)
	if type(rule.AddTag) == "table" then
		self._entityFactory:Add(entity, rule.AddTag.Key, rule.AddTag.FeatureName)
	end
	if type(rule.OnReached) == "function" then
		rule.OnReached({
			Entity = entity,
			Intent = intent,
			ApplyResult = applyResult,
			EntityFactory = self._entityFactory,
		})
	end
end

function MovementGoalReachedSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementGoalReachedSystem
