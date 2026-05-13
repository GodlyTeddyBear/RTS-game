--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	ActionKind = EnumList.new("ProximityServiceActionKind", {
		"Interact",
		"Talk",
		"Loot",
		"Use",
		"Custom",
	}),
	HandleState = EnumList.new("ProximityServiceHandleState", {
		"Registered",
		"Shown",
		"Hidden",
		"Disabled",
		"Destroyed",
	}),
	RegistrationMode = EnumList.new("ProximityServiceRegistrationMode", {
		"Create",
		"Register",
	}),
	ErrorKey = EnumList.new("ProximityServiceErrorKey", {
		"InvalidConfig",
		"InvalidKey",
		"InvalidTarget",
		"InvalidPrompt",
		"InvalidPromptName",
		"InvalidActionKind",
		"InvalidEnabled",
		"InvalidActionText",
		"InvalidObjectText",
		"InvalidHoldDuration",
		"InvalidMaxActivationDistance",
		"InvalidRequiresLineOfSight",
		"InvalidKeyboardKeyCode",
		"InvalidGamepadKeyCode",
		"InvalidExclusivity",
		"InvalidResolveParent",
		"InvalidCanShow",
		"InvalidCanTrigger",
		"InvalidCallback",
		"InvalidMetadata",
		"InvalidOwnsPrompt",
		"InvalidProfile",
		"InvalidResolvedParent",
		"InvalidMode",
		"ProximityServiceDestroyed",
		"ProximityHandleDestroyed",
		"IllegalProximityHandleTransition",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidConfig] = "ProximityService config must be a table when provided",
	[Enums.ErrorKey.InvalidKey] = "ProximityService key must be a non-empty string",
	[Enums.ErrorKey.InvalidTarget] = "ProximityService target must be a BasePart, Attachment, or Model",
	[Enums.ErrorKey.InvalidPrompt] = "ProximityService prompt must be a live ProximityPrompt",
	[Enums.ErrorKey.InvalidPromptName] = "ProximityService PromptName must be a non-empty string",
	[Enums.ErrorKey.InvalidActionKind] = "ProximityService ActionKind must belong to ProximityService.ActionKind",
	[Enums.ErrorKey.InvalidEnabled] = "ProximityService Enabled must be a boolean",
	[Enums.ErrorKey.InvalidActionText] = "ProximityService ActionText must be a string",
	[Enums.ErrorKey.InvalidObjectText] = "ProximityService ObjectText must be a string",
	[Enums.ErrorKey.InvalidHoldDuration] = "ProximityService HoldDuration must be a non-negative number",
	[Enums.ErrorKey.InvalidMaxActivationDistance] = "ProximityService MaxActivationDistance must be a positive number",
	[Enums.ErrorKey.InvalidRequiresLineOfSight] = "ProximityService RequiresLineOfSight must be a boolean",
	[Enums.ErrorKey.InvalidKeyboardKeyCode] = "ProximityService KeyboardKeyCode must be an Enum.KeyCode",
	[Enums.ErrorKey.InvalidGamepadKeyCode] = "ProximityService GamepadKeyCode must be an Enum.KeyCode",
	[Enums.ErrorKey.InvalidExclusivity] = "ProximityService Exclusivity must be an Enum.ProximityPromptExclusivity",
	[Enums.ErrorKey.InvalidResolveParent] = "ProximityService ResolveParent must be a function",
	[Enums.ErrorKey.InvalidCanShow] = "ProximityService CanShow must be a function",
	[Enums.ErrorKey.InvalidCanTrigger] = "ProximityService CanTrigger must be a function",
	[Enums.ErrorKey.InvalidCallback] = "ProximityService callbacks must be functions",
	[Enums.ErrorKey.InvalidMetadata] = "ProximityService Metadata must be a table",
	[Enums.ErrorKey.InvalidOwnsPrompt] = "ProximityService OwnsPrompt must be a boolean",
	[Enums.ErrorKey.InvalidProfile] = "ProximityService profile must be created by ProximityService.CreateProfile",
	[Enums.ErrorKey.InvalidResolvedParent] = "ProximityService resolved parent must be a live BasePart or Attachment",
	[Enums.ErrorKey.InvalidMode] = "ProximityService mode is invalid for this operation",
	[Enums.ErrorKey.ProximityServiceDestroyed] = "ProximityService has already been destroyed",
	[Enums.ErrorKey.ProximityHandleDestroyed] = "ProximityService handle has already been destroyed",
	[Enums.ErrorKey.IllegalProximityHandleTransition] = "ProximityService handle transition is not allowed",
})

return table.freeze(Enums)
