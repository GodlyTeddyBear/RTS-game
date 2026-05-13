--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	HandleState = EnumList.new("ClickServiceHandleState", {
		"Active",
		"Detached",
		"Destroyed",
	}),
	ErrorKey = EnumList.new("ClickServiceErrorKey", {
		"InvalidConfig",
		"InvalidTarget",
		"InvalidDetectorName",
		"InvalidMaxActivationDistance",
		"InvalidCursorIcon",
		"InvalidResolvePart",
		"InvalidResolvedPart",
		"ClickTargetResolutionFailed",
		"ClickTargetDestroyed",
		"ClickTargetAlreadyAttached",
		"ClickDetectorResolutionFailed",
		"ClickDetectorConflict",
		"ClickHandleDestroyed",
		"ClickServiceDestroyed",
		"IllegalClickHandleTransition",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidConfig] = "ClickService config must be a table when provided",
	[Enums.ErrorKey.InvalidTarget] = "ClickService target must be a BasePart or Model",
	[Enums.ErrorKey.InvalidDetectorName] = "ClickService detector name must be a non-empty string",
	[Enums.ErrorKey.InvalidMaxActivationDistance] = "ClickService MaxActivationDistance must be a positive number",
	[Enums.ErrorKey.InvalidCursorIcon] = "ClickService CursorIcon must be a string",
	[Enums.ErrorKey.InvalidResolvePart] = "ClickService ResolvePart must be a function",
	[Enums.ErrorKey.InvalidResolvedPart] = "ClickService resolved part must be a live BasePart",
	[Enums.ErrorKey.ClickTargetResolutionFailed] = "Click target could not resolve to a BasePart",
	[Enums.ErrorKey.ClickTargetDestroyed] = "Click target is not live",
	[Enums.ErrorKey.ClickTargetAlreadyAttached] = "Click target is already attached",
	[Enums.ErrorKey.ClickDetectorResolutionFailed] = "Click detector could not be created or normalized",
	[Enums.ErrorKey.ClickDetectorConflict] = "Configured detector name is occupied by a non-ClickDetector instance",
	[Enums.ErrorKey.ClickHandleDestroyed] = "Click handle has already been destroyed",
	[Enums.ErrorKey.ClickServiceDestroyed] = "Click service has already been destroyed",
	[Enums.ErrorKey.IllegalClickHandleTransition] = "Click handle transition is not allowed",
})

return table.freeze(Enums)
