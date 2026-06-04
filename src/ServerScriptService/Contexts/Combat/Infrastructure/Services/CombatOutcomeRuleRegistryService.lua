--!strict

local CombatOutcomeRuleRegistryService = {}
CombatOutcomeRuleRegistryService.__index = CombatOutcomeRuleRegistryService

function CombatOutcomeRuleRegistryService.new()
	return setmetatable({
		_movementPresentationRules = {},
		_healthDepletedRules = {},
		_goalReachedRules = {},
	}, CombatOutcomeRuleRegistryService)
end

function CombatOutcomeRuleRegistryService:RegisterMovementPresentationRule(payload: any)
	local ruleId = payload.RuleId
	if type(ruleId) ~= "string" or ruleId == "" then
		return false
	end
	if self._movementPresentationRules[ruleId] ~= nil then
		return true
	end
	self._movementPresentationRules[ruleId] = table.freeze(table.clone(payload))
	return true
end

function CombatOutcomeRuleRegistryService:RegisterHealthDepletedRule(payload: any)
	local outcomeId = payload.OutcomeId or payload.VictimKind
	if type(outcomeId) ~= "string" or outcomeId == "" then
		return false
	end
	local rule = table.clone(payload)
	rule.OutcomeId = outcomeId
	self._healthDepletedRules[outcomeId] = table.freeze(rule)
	return true
end

function CombatOutcomeRuleRegistryService:RegisterGoalReachedRule(payload: any)
	local ruleId = payload.OutcomeId or payload.RuleId
	if type(ruleId) ~= "string" or ruleId == "" then
		return false
	end
	if self._goalReachedRules[ruleId] ~= nil then
		return true
	end
	self._goalReachedRules[ruleId] = table.freeze(table.clone(payload))
	return true
end

function CombatOutcomeRuleRegistryService:GetMovementPresentationRules(): { any }
	local rules = {}
	for _, rule in pairs(self._movementPresentationRules) do
		table.insert(rules, rule)
	end
	return rules
end

function CombatOutcomeRuleRegistryService:GetHealthDepletedRule(victimKind: string): any?
	return self._healthDepletedRules[victimKind]
end

function CombatOutcomeRuleRegistryService:GetGoalReachedRule(outcomeId: string): any?
	return self._goalReachedRules[outcomeId]
end

function CombatOutcomeRuleRegistryService:GetGoalReachedRules(): { any }
	local rules = {}
	for _, rule in pairs(self._goalReachedRules) do
		table.insert(rules, rule)
	end
	return rules
end

return CombatOutcomeRuleRegistryService
