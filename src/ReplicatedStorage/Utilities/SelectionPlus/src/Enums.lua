--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	HandleState = EnumList.new("SelectionPlusHandleState", {
		"Active",
		"Cleared",
		"Destroyed",
	}),
	SelectionMode = EnumList.new("SelectionPlusSelectionMode", {
		"Single",
		"Set",
	}),
	InvalidationReason = EnumList.new("SelectionPlusInvalidationReason", {
		"TargetDestroyed",
		"AdorneeInvalid",
		"ResolverFailed",
		"CallerCleared",
	}),
	ErrorKey = EnumList.new("SelectionPlusErrorKey", {
		"InvalidConfig",
		"InvalidChannelName",
		"InvalidTarget",
		"InvalidTargetList",
		"InvalidResolverOptions",
		"InvalidHighlightOptions",
		"InvalidRadiusOptions",
		"InvalidMetadata",
		"InvalidSelectionMode",
		"SelectionServiceDestroyed",
		"SelectionHandleDestroyed",
		"IllegalSelectionHandleTransition",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidConfig] = "SelectionPlus config must be a table when provided",
	[Enums.ErrorKey.InvalidChannelName] = "SelectionPlus channelName must be a non-empty string",
	[Enums.ErrorKey.InvalidTarget] = "SelectionPlus target must be an Instance or resolved target",
	[Enums.ErrorKey.InvalidTargetList] = "SelectionPlus Targets must be a non-empty array",
	[Enums.ErrorKey.InvalidResolverOptions] = "SelectionPlus ResolverOptions are invalid",
	[Enums.ErrorKey.InvalidHighlightOptions] = "SelectionPlus Highlight options are invalid",
	[Enums.ErrorKey.InvalidRadiusOptions] = "SelectionPlus Radius options are invalid",
	[Enums.ErrorKey.InvalidMetadata] = "SelectionPlus Metadata must be a table",
	[Enums.ErrorKey.InvalidSelectionMode] = "SelectionPlus selection mode must belong to SelectionPlus.SelectionMode",
	[Enums.ErrorKey.SelectionServiceDestroyed] = "SelectionPlus manager has already been destroyed",
	[Enums.ErrorKey.SelectionHandleDestroyed] = "SelectionPlus handle has already been destroyed",
	[Enums.ErrorKey.IllegalSelectionHandleTransition] = "SelectionPlus handle transition is not allowed",
})

return table.freeze(Enums)
