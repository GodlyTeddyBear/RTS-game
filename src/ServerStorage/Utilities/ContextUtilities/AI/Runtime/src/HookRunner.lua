--!strict

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type THook = Types.THook
type THookContext = Types.THookContext

export type THookOutcome = {
	Facts: { [string]: any },
	BehaviorContext: { [string]: any },
	BaseServices: { [string]: any }?,
	ServiceOverrides: { [any]: any }?,
}

local EMPTY_BUCKET = table.freeze({})

local function _MergeBucket(
	target: { [any]: any }?,
	source: { [string]: any }?
): { [any]: any }?
	if source == nil then
		return target
	end

	local resolvedTarget = target
	if resolvedTarget == nil then
		resolvedTarget = {}
	end

	for key, value in pairs(source) do
		resolvedTarget[key] = value
	end

	return resolvedTarget
end

local HookRunner = {}

function HookRunner.Run(hooks: { THook }, entity: number, hookContext: THookContext): THookOutcome
	-- Hooks contribute in order so later modules can intentionally override earlier buckets.
	local facts = if hookContext.NeedsFacts then {} else nil
	local behaviorContext = if hookContext.NeedsBehaviorContext then {} else nil
	local serviceOverrides = nil

	for index, hook in ipairs(hooks) do
		local contribution = hook:Use(entity, hookContext)
		if contribution == nil then
			continue
		end

		Validation.ValidateHookContribution(index, contribution)
		Validation.ValidateBehaviorContextReservedKeys(index, contribution.BehaviorContext)

		_MergeBucket(facts, contribution.Facts)
		_MergeBucket(behaviorContext, contribution.BehaviorContext)
		if hookContext.NeedsServices then
			serviceOverrides = _MergeBucket(serviceOverrides, contribution.Services)
		end
	end

	return {
		Facts = if facts ~= nil then facts else EMPTY_BUCKET,
		BehaviorContext = if behaviorContext ~= nil then behaviorContext else EMPTY_BUCKET,
		BaseServices = if hookContext.NeedsServices then hookContext.Services else nil,
		ServiceOverrides = serviceOverrides,
	}
end

return table.freeze(HookRunner)
