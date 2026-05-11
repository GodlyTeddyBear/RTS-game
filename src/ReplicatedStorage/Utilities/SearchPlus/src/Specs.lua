--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TSearchOptions = Types.TSearchOptions

local FILTER_FIELDS = table.freeze({
	"IncludeScopeRoot",
	"Recursive",
	"MaxDepth",
	"IncludeRoot",
	"Name",
	"Names",
	"CaseInsensitiveName",
	"ClassName",
	"ClassNames",
	"IsA",
	"IsAAny",
	"Attributes",
	"Tags",
	"TagsAny",
	"Instances",
	"ExcludeInstances",
	"AncestorOf",
	"DescendantOf",
	"Predicate",
	"ExcludeAttributes",
	"ExcludeTags",
	"ExcludePredicate",
})

local SearchSpecs = {}

function SearchSpecs.HasSelector(options: TSearchOptions): boolean
	return type(options.Selector) == "string" and options.Selector ~= ""
end

function SearchSpecs.HasPath(options: TSearchOptions): boolean
	return options.Path ~= nil
end

function SearchSpecs.HasFilterFields(options: TSearchOptions): boolean
	local candidate = options :: any
	for _, fieldName in FILTER_FIELDS do
		if candidate[fieldName] ~= nil then
			return true
		end
	end

	return false
end

function SearchSpecs.IsSelectorRequest(options: TSearchOptions): boolean
	return SearchSpecs.HasSelector(options)
		and not SearchSpecs.HasPath(options)
end

function SearchSpecs.IsPathRequest(options: TSearchOptions): boolean
	return SearchSpecs.HasPath(options)
		and not SearchSpecs.HasSelector(options)
end

function SearchSpecs.IsFilterRequest(options: TSearchOptions): boolean
	return not SearchSpecs.HasSelector(options)
		and not SearchSpecs.HasPath(options)
		and SearchSpecs.HasFilterFields(options)
end

function SearchSpecs.HasMixedModes(options: TSearchOptions): boolean
	local modeCount = 0

	if SearchSpecs.HasSelector(options) then
		modeCount += 1
	end

	if SearchSpecs.HasPath(options) then
		modeCount += 1
	end

	return modeCount > 1
end

function SearchSpecs.HasMixedScopes(options: TSearchOptions): boolean
	return options.ScopePath ~= nil and options.ScopeSelector ~= nil
end

function SearchSpecs.HasValidMaxDepth(options: TSearchOptions): boolean
	local depthValues = {
		options.MaxDepth,
		options.ScopeMaxDepth,
	}

	for _, depth in depthValues do
		if depth == nil then
			continue
		end

		if type(depth) ~= "number" or depth <= 0 or depth % 1 ~= 0 then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidPath(options: TSearchOptions): boolean
	local paths = {
		options.Path,
		options.ScopePath,
	}

	for _, path in paths do
		if path == nil then
			continue
		end

		if type(path) ~= "table" or #path == 0 then
			return false
		end

		for _, segment in path do
			if type(segment) ~= "string" or segment == "" then
				return false
			end
		end
	end

	return true
end

function SearchSpecs.HasValidTags(options: TSearchOptions): boolean
	local tagLists = {
		options.Tags,
		options.TagsAny,
		options.ExcludeTags,
	}

	for _, tags in tagLists do
		if tags == nil then
			continue
		end

		if type(tags) ~= "table" or #tags == 0 then
			return false
		end

		for _, tagName in tags do
			if type(tagName) ~= "string" or tagName == "" then
				return false
			end
		end
	end

	return true
end

function SearchSpecs.HasValidMatcherLists(options: TSearchOptions): boolean
	local lists = {
		options.Names,
		options.ClassNames,
		options.IsAAny,
	}

	for _, values in lists do
		if values == nil then
			continue
		end

		if type(values) ~= "table" or #values == 0 then
			return false
		end

		for _, value in values do
			if type(value) ~= "string" or value == "" then
				return false
			end
		end
	end

	return true
end

function SearchSpecs.HasValidAttributes(options: TSearchOptions): boolean
	local attributeTables = {
		options.Attributes,
		options.ExcludeAttributes,
	}

	for _, attributes in attributeTables do
		if attributes ~= nil and type(attributes) ~= "table" then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidInstanceFilters(options: TSearchOptions): boolean
	local instanceLists = {
		options.Instances,
		options.ExcludeInstances,
	}

	for _, instances in instanceLists do
		if instances == nil then
			continue
		end

		if type(instances) ~= "table" then
			return false
		end

		for _, instance in instances do
			if typeof(instance) ~= "Instance" then
				return false
			end
		end
	end

	local singleInstances = {
		options.AncestorOf,
		options.DescendantOf,
	}

	for _, instance in singleInstances do
		if instance ~= nil and typeof(instance) ~= "Instance" then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidPredicate(options: TSearchOptions): boolean
	local predicates = {
		options.Predicate,
		options.ExcludePredicate,
	}

	for _, predicate in predicates do
		if predicate ~= nil and type(predicate) ~= "function" then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidScopeSelector(options: TSearchOptions): boolean
	local selector = options.ScopeSelector
	return selector == nil or (type(selector) == "string" and selector ~= "")
end

function SearchSpecs.HasValidRequestShape(options: TSearchOptions): boolean
	if SearchSpecs.HasMixedModes(options) then
		return false
	end

	return SearchSpecs.IsSelectorRequest(options)
		or SearchSpecs.IsPathRequest(options)
		or SearchSpecs.IsFilterRequest(options)
end

local HasOneRequestMode = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.MissingRequestMode],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidRequestShape(options)
end)

local HasNoMixedModes = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.MixedRequestModes],
	function(options: TSearchOptions)
	return not SearchSpecs.HasMixedModes(options)
end)

local HasNoMixedScopes = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.MixedScopeModes],
	function(options: TSearchOptions)
	return not SearchSpecs.HasMixedScopes(options)
end)

local HasValidPath = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPath],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidPath(options)
end)

local HasValidScopeSelector = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidScopeSelector],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidScopeSelector(options)
end)

local HasValidMaxDepth = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMaxDepth],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidMaxDepth(options)
end)

local HasValidTags = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidTags],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidTags(options)
end)

local HasValidMatcherLists = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMatcherList],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidMatcherLists(options)
end)

local HasValidAttributes = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidAttributes],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidAttributes(options)
end)

local HasValidInstanceFilters = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidInstanceFilter],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidInstanceFilters(options)
end)

local HasValidPredicate = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPredicate],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidPredicate(options)
end)

SearchSpecs.HasOneRequestMode = HasOneRequestMode
SearchSpecs.HasNoMixedModes = HasNoMixedModes
SearchSpecs.HasNoMixedScopes = HasNoMixedScopes
SearchSpecs.HasValidPathSpec = HasValidPath
SearchSpecs.HasValidScopeSelectorSpec = HasValidScopeSelector
SearchSpecs.HasValidMaxDepthSpec = HasValidMaxDepth
SearchSpecs.HasValidTagsSpec = HasValidTags
SearchSpecs.HasValidMatcherListsSpec = HasValidMatcherLists
SearchSpecs.HasValidAttributesSpec = HasValidAttributes
SearchSpecs.HasValidInstanceFiltersSpec = HasValidInstanceFilters
SearchSpecs.HasValidPredicateSpec = HasValidPredicate
SearchSpecs.CanResolveRequest = Spec.All({
	HasNoMixedModes,
	HasNoMixedScopes,
	HasOneRequestMode,
	HasValidPath,
	HasValidScopeSelector,
	HasValidMaxDepth,
	HasValidTags,
	HasValidMatcherLists,
	HasValidAttributes,
	HasValidInstanceFilters,
	HasValidPredicate,
})

return table.freeze(SearchSpecs)
