--!strict

local MovementGoalReachedSystem = {}
MovementGoalReachedSystem.__index = MovementGoalReachedSystem

function MovementGoalReachedSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({ _entityFactory = entityFactory, _ruleRegistry = ruleRegistry }, MovementGoalReachedSystem)
end

function MovementGoalReachedSystem:Run()
	-- READS: Movement.MoveIntent [AUTHORITATIVE], Movement.ApplyResult [AUTHORITATIVE]
	-- WRITES: configured goal reached tags and request components
	local result = self._entityFactory:Query({
		Keys = {
			{ Key = "MoveIntent", FeatureName = "Movement" },
			{ Key = "ApplyResult", FeatureName = "Movement" },
			{ Key = "GoalReachedOutcome", FeatureName = "Entity" },
		},
	})
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		local intent = self:_Get(entity, "MoveIntent", "Movement")
		local applyResult = self:_Get(entity, "ApplyResult", "Movement")
		local outcome = self:_Get(entity, "GoalReachedOutcome", "Entity")
		local outcomeId = if type(outcome) == "table" then outcome.OutcomeId else nil
		if type(outcomeId) == "string"
			and type(intent) == "table"
			and type(applyResult) == "table"
			and applyResult.IsDone == true
		then
			local rule = self._ruleRegistry:GetGoalReachedRule(outcomeId)
			if type(rule) == "table" and (rule.ActionId == nil or intent.ActionId == rule.ActionId) then
				self:_ApplyRule(rule, entity, intent, applyResult)
			end
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
