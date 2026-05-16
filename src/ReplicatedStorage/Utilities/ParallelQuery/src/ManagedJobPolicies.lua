--!strict

local Types = require(script.Parent.Types)

type TManagedJobPolicyConfig = Types.TManagedJobPolicyConfig
type TManagedJobPolicyPreset = Types.TManagedJobPolicyPreset

local DEFAULT_POLICY_PRESET: TManagedJobPolicyPreset = "StrictFreshOnly"

local ManagedJobPolicies = {
	StrictFreshOnly = "StrictFreshOnly",
	KeepLastGood = "KeepLastGood",
	ApplyFreshOrMarkFallback = "ApplyFreshOrMarkFallback",
}

local function _IsPreset(value: any): boolean
	return value == "StrictFreshOnly" or value == "KeepLastGood" or value == "ApplyFreshOrMarkFallback"
end

function ManagedJobPolicies.Resolve(policyConfig: TManagedJobPolicyPreset | TManagedJobPolicyConfig?): TManagedJobPolicyPreset
	if policyConfig == nil then
		return DEFAULT_POLICY_PRESET
	end

	if type(policyConfig) == "string" then
		assert(_IsPreset(policyConfig), `Unknown managed job policy preset "{tostring(policyConfig)}"`)
		return policyConfig
	end

	assert(type(policyConfig) == "table", "Managed job Policy must be a preset string or config table")
	assert(_IsPreset(policyConfig.Preset), `Unknown managed job policy preset "{tostring(policyConfig.Preset)}"`)
	return policyConfig.Preset
end

return table.freeze(ManagedJobPolicies)
