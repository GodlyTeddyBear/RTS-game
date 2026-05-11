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
		"MixedScopeModes",
		"InvalidPath",
		"InvalidScopeSelector",
		"InvalidMaxDepth",
		"InvalidTags",
		"InvalidMatcherList",
		"InvalidInstanceFilter",
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
	[Enums.ErrorKey.MixedScopeModes] = "SearchPlus ScopePath and ScopeSelector are mutually exclusive",
	[Enums.ErrorKey.InvalidPath] = "SearchPlus Path and ScopePath must be non-empty arrays of non-empty strings",
	[Enums.ErrorKey.InvalidScopeSelector] = "SearchPlus ScopeSelector must be a non-empty string",
	[Enums.ErrorKey.InvalidMaxDepth] = "SearchPlus MaxDepth and ScopeMaxDepth must be positive integers",
	[Enums.ErrorKey.InvalidTags] = "SearchPlus Tags, TagsAny, and ExcludeTags must be non-empty arrays of non-empty strings",
	[Enums.ErrorKey.InvalidMatcherList] = "SearchPlus Names, ClassNames, and IsAAny must be non-empty arrays of non-empty strings",
	[Enums.ErrorKey.InvalidInstanceFilter] = "SearchPlus Instances and ExcludeInstances must be arrays of Instance values, and AncestorOf and DescendantOf must be Instance values",
	[Enums.ErrorKey.InvalidAttributes] = "SearchPlus Attributes and ExcludeAttributes must be tables",
	[Enums.ErrorKey.InvalidPredicate] = "SearchPlus Predicate and ExcludePredicate must be functions",
	[Enums.ErrorKey.InvalidRoot] = "SearchPlus requires a root Instance",
	[Enums.ErrorKey.FindOneNoMatches] = "SearchPlus expected exactly one match, got zero",
	[Enums.ErrorKey.FindOneMultipleMatches] = "SearchPlus expected exactly one match, got multiple",
})

return table.freeze(Enums)
