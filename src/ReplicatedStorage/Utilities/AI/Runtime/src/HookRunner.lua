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
local EMPTY_BUCKET = table.freeze({})

local HookRunner = {}

function HookRunner.Run(hooks: { THook }, entity: number, hookContext: THookContext): THookOutcome
	-- Hooks contribute in order so later modules can intentionally override earlier buckets.
	local facts = if hookContext.NeedsFacts then {} else nil
	local behaviorContext = if hookContext.NeedsBehaviorContext then {} else nil
	local mergedServices = if hookContext.NeedsServices then table.clone(hookContext.Services) else nil

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
		Facts = if facts ~= nil then facts else EMPTY_BUCKET,
		BehaviorContext = if behaviorContext ~= nil then behaviorContext else EMPTY_BUCKET,
		Services = if mergedServices ~= nil then mergedServices else EMPTY_BUCKET,
	}
end

function _MergeBucket(target: { [string]: any }?, source: { [string]: any }?)
	if target == nil or source == nil then
		return
	end

	for key, value in pairs(source) do
		target[key] = value
	end
end

return table.freeze(HookRunner)
