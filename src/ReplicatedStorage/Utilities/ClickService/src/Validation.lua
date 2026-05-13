--!strict

local Types = require(script.Parent.Types)

type TClickAttachOptions = Types.TClickAttachOptions
type TClickManagerConfig = Types.TClickManagerConfig
type TResolvedClickOptions = Types.TResolvedClickOptions

local DEFAULT_DETECTOR_NAME = "ClickServiceDetector"

local Validation = {}

local function _CloneOptions(options: TClickAttachOptions?): TClickAttachOptions
	if options == nil then
		return {}
	end

	return table.clone(options)
end

function Validation.NormalizeManagerConfig(config: TClickManagerConfig?): TResolvedClickOptions
	local normalizedConfig = _CloneOptions(config)

	return table.freeze({
		Name = normalizedConfig.Name or DEFAULT_DETECTOR_NAME,
		MaxActivationDistance = normalizedConfig.MaxActivationDistance,
		CursorIcon = normalizedConfig.CursorIcon,
		ResolvePart = normalizedConfig.ResolvePart,
	})
end

function Validation.ResolveAttachOptions(
	managerConfig: TResolvedClickOptions,
	options: TClickAttachOptions?
): TResolvedClickOptions
	local overrides = _CloneOptions(options)

	return table.freeze({
		Name = overrides.Name or managerConfig.Name,
		MaxActivationDistance = if overrides.MaxActivationDistance ~= nil
			then overrides.MaxActivationDistance
			else managerConfig.MaxActivationDistance,
		CursorIcon = if overrides.CursorIcon ~= nil then overrides.CursorIcon else managerConfig.CursorIcon,
		ResolvePart = if overrides.ResolvePart ~= nil then overrides.ResolvePart else managerConfig.ResolvePart,
	})
end

return table.freeze(Validation)
