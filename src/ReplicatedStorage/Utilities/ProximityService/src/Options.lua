--!strict

local Types = require(script.Parent.Types)

type TProximityOptions = Types.TProximityOptions

local Options = {}

local function _CloneDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.clone(value)
end

function Options.Create(spec: TProximityOptions?): TProximityOptions
	if spec == nil then
		return {}
	end

	return {
		PromptName = spec.PromptName,
		ActionKind = spec.ActionKind,
		Enabled = spec.Enabled,
		ActionText = spec.ActionText,
		ObjectText = spec.ObjectText,
		HoldDuration = spec.HoldDuration,
		MaxActivationDistance = spec.MaxActivationDistance,
		RequiresLineOfSight = spec.RequiresLineOfSight,
		KeyboardKeyCode = spec.KeyboardKeyCode,
		GamepadKeyCode = spec.GamepadKeyCode,
		Exclusivity = spec.Exclusivity,
		ResolveParent = spec.ResolveParent,
		CanShow = spec.CanShow,
		CanTrigger = spec.CanTrigger,
		OnShown = spec.OnShown,
		OnHidden = spec.OnHidden,
		OnTriggered = spec.OnTriggered,
		OnHoldStarted = spec.OnHoldStarted,
		OnHoldEnded = spec.OnHoldEnded,
		Metadata = _CloneDictionary(spec.Metadata),
		OwnsPrompt = spec.OwnsPrompt,
	}
end

function Options.Merge(baseOptions: TProximityOptions?, overrideOptions: TProximityOptions?): TProximityOptions
	local mergedOptions = Options.Create(baseOptions)
	local overrides = Options.Create(overrideOptions)

	for key, value in pairs(overrides) do
		(mergedOptions :: any)[key] = value
	end

	return mergedOptions
end

return table.freeze(Options)
