--!strict

local EntityPayloadSpecs = {}

local function _IsNonEmptyString(value: any): boolean
	return type(value) == "string" and value ~= ""
end

function EntityPayloadSpecs.IsNonEmptyFeatureName(value: any): boolean
	return _IsNonEmptyString(value)
end

function EntityPayloadSpecs.IsTable(value: any): boolean
	return type(value) == "table"
end

function EntityPayloadSpecs.IsRequiredFunction(value: any): boolean
	return type(value) == "function"
end

function EntityPayloadSpecs.IsOptionalFunction(value: any): boolean
	return value == nil or type(value) == "function"
end

function EntityPayloadSpecs.HasMatchingFeatureName(payload: any, featureName: string): boolean
	return type(payload) == "table" and payload.FeatureName == featureName
end

function EntityPayloadSpecs.IsSupportedAIRuntimeKind(value: any): boolean
	return value == "Combat"
end

function EntityPayloadSpecs.IsSupportedDependencyMode(value: any): boolean
	return value == "EntityContextOnly"
end

function EntityPayloadSpecs.IsSupportedDeclaredDependency(value: any): boolean
	return value == "EntityContext" or value == "RuntimeServices"
end

function EntityPayloadSpecs.IsValidQuerySpec(value: any): boolean
	if type(value) == "string" then
		return value ~= ""
	end

	if type(value) ~= "table" then
		return false
	end

	if type(value.Key) == "string" then
		return value.Key ~= ""
	end

	if type(value.Keys) == "table" then
		return true
	end

	return #value > 0
end

return table.freeze(EntityPayloadSpecs)
