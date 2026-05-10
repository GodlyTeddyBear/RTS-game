--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	SearchMode = EnumList.new("SearchPlusSearchMode", {
		"Selector",
		"Path",
		"Filter",
	}),
	ErrorKey = EnumList.new("SearchPlusErrorKey", {
		"InvalidOptions",
		"MissingRequestMode",
		"MixedRequestModes",
		"InvalidPath",
		"InvalidMaxDepth",
		"InvalidTags",
		"InvalidAttributes",
		"InvalidPredicate",
		"InvalidRoot",
		"FindOneNoMatches",
		"FindOneMultipleMatches",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidOptions] = "SearchPlus requires an options table",
	[Enums.ErrorKey.MissingRequestMode] = "SearchPlus requires Selector, Path, or at least one filter field",
	[Enums.ErrorKey.MixedRequestModes] = "SearchPlus request modes are mutually exclusive",
	[Enums.ErrorKey.InvalidPath] = "SearchPlus Path must be a non-empty array of non-empty strings",
	[Enums.ErrorKey.InvalidMaxDepth] = "SearchPlus MaxDepth must be a positive integer",
	[Enums.ErrorKey.InvalidTags] = "SearchPlus Tags must be a non-empty array of non-empty strings",
	[Enums.ErrorKey.InvalidAttributes] = "SearchPlus Attributes must be a table",
	[Enums.ErrorKey.InvalidPredicate] = "SearchPlus Predicate must be a function",
	[Enums.ErrorKey.InvalidRoot] = "SearchPlus requires a root Instance",
	[Enums.ErrorKey.FindOneNoMatches] = "SearchPlus expected exactly one match, got zero",
	[Enums.ErrorKey.FindOneMultipleMatches] = "SearchPlus expected exactly one match, got multiple",
})

return table.freeze(Enums)
