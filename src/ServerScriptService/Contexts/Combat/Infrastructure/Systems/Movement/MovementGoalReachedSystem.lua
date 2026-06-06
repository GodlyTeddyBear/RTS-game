--!strict

local MovementGoalReachedSystem = {}
MovementGoalReachedSystem.__index = MovementGoalReachedSystem

function MovementGoalReachedSystem.new(entityFactory: any, ruleRegistry: any)
	return setmetatable({ _entityFactory = entityFactory, _ruleRegistry = ruleRegistry }, MovementGoalReachedSystem)
end

function MovementGoalReachedSystem:Run()
	-- READS: Movement.CompletedIntent [DERIVED], Entity.GoalReachedOutcome [AUTHORITATIVE]
	-- WRITES: Combat.GoalReachedOutcomeRequest [AUTHORITATIVE], Movement.CompletedIntent [DERIVED]
	local result = self._entityFactory:Query({
		Keys = {
			{ Key = "CompletedIntent", FeatureName = "Movement" },
		},
	})
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		local completedIntent = self:_Get(entity, "CompletedIntent", "Movement")
		local outcome = self:_Get(entity, "GoalReachedOutcome", "Entity")
		local outcomeId = if type(outcome) == "table" then outcome.OutcomeId else nil
		if type(completedIntent) == "table" then
			if type(outcomeId) == "string" then
				local rule = self._ruleRegistry:GetGoalReachedRule(outcomeId)
				if type(rule) == "table" and (rule.ActionId == nil or completedIntent.ActionId == rule.ActionId) then
					self:_ApplyRule(rule, entity, completedIntent)
				end
			end
			self._entityFactory:Remove(entity, "CompletedIntent", "Movement")
		end
	end
end

function MovementGoalReachedSystem:_ApplyRule(rule: any, entity: number, completedIntent: any)
	self._entityFactory:CreateFromArchetype("Combat.GoalReachedOutcomeRequest", {
		GoalReachedOutcomeRequest = {
			SourceEntity = entity,
			OutcomeId = rule.OutcomeId,
			ActionId = completedIntent.ActionId,
			CreatedAt = os.clock(),
			ExpiresAt = os.clock() + 1,
		},
	})
end

function MovementGoalReachedSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementGoalReachedSystem
