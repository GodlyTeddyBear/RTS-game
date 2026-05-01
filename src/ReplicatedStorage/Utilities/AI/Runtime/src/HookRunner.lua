--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type THook = Types.THook
type THookContext = Types.THookContext

export type THookOutcome = {
	Facts: { [string]: any },
	BehaviorContext: { [string]: any },
	Services: { [string]: any },
}

local _MergeBucket

local HookRunner = {}

function HookRunner.Run(hooks: { THook }, entity: number, hookContext: THookContext): THookOutcome
	-- Hooks contribute in order so later modules can intentionally override earlier buckets.
	local facts = {}
	local behaviorContext = {}
	local mergedServices = table.clone(hookContext.Services)

	for index, hook in ipairs(hooks) do
		local contribution = hook:Use(entity, hookContext)
		if contribution == nil then
			continue
		end

		Validation.ValidateHookContribution(index, contribution)
		Validation.ValidateBehaviorContextReservedKeys(index, contribution.BehaviorContext)

		_MergeBucket(facts, contribution.Facts)
		_MergeBucket(behaviorContext, contribution.BehaviorContext)
		_MergeBucket(mergedServices, contribution.Services)
	end

	return {
		Facts = facts,
		BehaviorContext = behaviorContext,
		Services = mergedServices,
	}
end

function _MergeBucket(target: { [string]: any }, source: { [string]: any }?)
	if source == nil then
		return
	end

	for key, value in pairs(source) do
		target[key] = value
	end
end

return table.freeze(HookRunner)
