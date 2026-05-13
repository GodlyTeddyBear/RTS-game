--!strict

local Types = require(script.Parent.Types)
local Enums = require(script.Parent.Enums)
local Options = require(script.Parent.Options)

type TProximityOptions = Types.TProximityOptions
type TProximityManagerConfig = Types.TProximityManagerConfig
type TResolvedProximityOptions = Types.TResolvedProximityOptions

local DEFAULT_PROMPT_NAME = "ProximityServicePrompt"
local DEFAULT_ACTION_TEXT = "Interact"
local DEFAULT_OBJECT_TEXT = ""
local DEFAULT_MAX_ACTIVATION_DISTANCE = 10

local Validation = {}

local function _CloneFrozenDictionary(value: { [string]: any }?): { [string]: any }?
	if value == nil then
		return nil
	end

	return table.freeze(table.clone(value))
end

local function _NormalizeOptions(options: TProximityOptions): TResolvedProximityOptions
	return table.freeze({
		PromptName = options.PromptName or DEFAULT_PROMPT_NAME,
		ActionKind = options.ActionKind or Enums.ActionKind.Interact,
		Enabled = if options.Enabled ~= nil then options.Enabled else true,
		ActionText = if options.ActionText ~= nil then options.ActionText else DEFAULT_ACTION_TEXT,
		ObjectText = if options.ObjectText ~= nil then options.ObjectText else DEFAULT_OBJECT_TEXT,
		HoldDuration = if options.HoldDuration ~= nil then options.HoldDuration else 0,
		MaxActivationDistance = if options.MaxActivationDistance ~= nil
			then options.MaxActivationDistance
			else DEFAULT_MAX_ACTIVATION_DISTANCE,
		RequiresLineOfSight = if options.RequiresLineOfSight ~= nil then options.RequiresLineOfSight else true,
		KeyboardKeyCode = if options.KeyboardKeyCode ~= nil then options.KeyboardKeyCode else Enum.KeyCode.E,
		GamepadKeyCode = if options.GamepadKeyCode ~= nil then options.GamepadKeyCode else Enum.KeyCode.ButtonX,
		Exclusivity = if options.Exclusivity ~= nil
			then options.Exclusivity
			else Enum.ProximityPromptExclusivity.OnePerButton,
		ResolveParent = options.ResolveParent,
		CanShow = options.CanShow,
		CanTrigger = options.CanTrigger,
		OnShown = options.OnShown,
		OnHidden = options.OnHidden,
		OnTriggered = options.OnTriggered,
		OnHoldStarted = options.OnHoldStarted,
		OnHoldEnded = options.OnHoldEnded,
		Metadata = _CloneFrozenDictionary(options.Metadata),
		OwnsPrompt = if options.OwnsPrompt ~= nil then options.OwnsPrompt else false,
	})
end

function Validation.NormalizeManagerConfig(config: TProximityManagerConfig?): TResolvedProximityOptions
	return _NormalizeOptions(Options.Create(config))
end

function Validation.ResolveOptions(
	baseOptions: TResolvedProximityOptions,
	options: TProximityOptions?
): TResolvedProximityOptions
	local mergedOptions = Options.Merge(baseOptions :: any, options)
	return _NormalizeOptions(mergedOptions)
end

return table.freeze(Validation)
