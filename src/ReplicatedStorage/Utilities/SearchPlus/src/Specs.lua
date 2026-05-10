--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TSearchOptions = Types.TSearchOptions

local FILTER_FIELDS = table.freeze({
	"Recursive",
	"MaxDepth",
	"Name",
	"CaseInsensitiveName",
	"ClassName",
	"IsA",
	"Attributes",
	"Tags",
	"Predicate",
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
		and not SearchSpecs.HasFilterFields(options)
end

function SearchSpecs.IsPathRequest(options: TSearchOptions): boolean
	return SearchSpecs.HasPath(options)
		and not SearchSpecs.HasSelector(options)
		and not SearchSpecs.HasFilterFields(options)
end

function SearchSpecs.IsFilterRequest(options: TSearchOptions): boolean
	return SearchSpecs.HasFilterFields(options)
		and not SearchSpecs.HasSelector(options)
		and not SearchSpecs.HasPath(options)
end

function SearchSpecs.HasMixedModes(options: TSearchOptions): boolean
	local modeCount = 0

	if SearchSpecs.HasSelector(options) then
		modeCount += 1
	end

	if SearchSpecs.HasPath(options) then
		modeCount += 1
	end

	if SearchSpecs.HasFilterFields(options) then
		modeCount += 1
	end

	return modeCount > 1
end

function SearchSpecs.HasValidMaxDepth(options: TSearchOptions): boolean
	if options.MaxDepth == nil then
		return true
	end

	return type(options.MaxDepth) == "number"
		and options.MaxDepth > 0
		and options.MaxDepth % 1 == 0
end

function SearchSpecs.HasValidPath(options: TSearchOptions): boolean
	local path = options.Path
	if path == nil then
		return true
	end

	if type(path) ~= "table" or #path == 0 then
		return false
	end

	for _, segment in path do
		if type(segment) ~= "string" or segment == "" then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidTags(options: TSearchOptions): boolean
	local tags = options.Tags
	if tags == nil then
		return true
	end

	if type(tags) ~= "table" or #tags == 0 then
		return false
	end

	for _, tagName in tags do
		if type(tagName) ~= "string" or tagName == "" then
			return false
		end
	end

	return true
end

function SearchSpecs.HasValidAttributes(options: TSearchOptions): boolean
	local attributes = options.Attributes
	return attributes == nil or type(attributes) == "table"
end

function SearchSpecs.HasValidPredicate(options: TSearchOptions): boolean
	local predicate = options.Predicate
	return predicate == nil or type(predicate) == "function"
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

local HasValidPath = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPath],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidPath(options)
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

local HasValidAttributes = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidAttributes],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidAttributes(options)
end)

local HasValidPredicate = Spec.new(
	"InvalidSearchRequest",
	Enums.ErrorMessage[Enums.ErrorKey.InvalidPredicate],
	function(options: TSearchOptions)
	return SearchSpecs.HasValidPredicate(options)
end)

SearchSpecs.HasOneRequestMode = HasOneRequestMode
SearchSpecs.HasNoMixedModes = HasNoMixedModes
SearchSpecs.HasValidPathSpec = HasValidPath
SearchSpecs.HasValidMaxDepthSpec = HasValidMaxDepth
SearchSpecs.HasValidTagsSpec = HasValidTags
SearchSpecs.HasValidAttributesSpec = HasValidAttributes
SearchSpecs.HasValidPredicateSpec = HasValidPredicate
SearchSpecs.CanResolveRequest = Spec.All({
	HasNoMixedModes,
	HasOneRequestMode,
	HasValidPath,
	HasValidMaxDepth,
	HasValidTags,
	HasValidAttributes,
	HasValidPredicate,
})

return table.freeze(SearchSpecs)
