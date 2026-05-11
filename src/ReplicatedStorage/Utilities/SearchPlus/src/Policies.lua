--!strict

local Enums = require(script.Parent.Enums)
local Specs = require(script.Parent.Specs)
local Types = require(script.Parent.Types)

type TSearchOptions = Types.TSearchOptions
type TResolvedSearchMode = Types.TResolvedSearchMode
type TResolvedSearchOptions = Types.TResolvedSearchOptions

local Policies = {}

local VALIDATION_SPECS = table.freeze({
	Specs.HasNoMixedModes,
	Specs.HasNoMixedScopes,
	Specs.HasOneRequestMode,
	Specs.HasValidPathSpec,
	Specs.HasValidScopeSelectorSpec,
	Specs.HasValidMaxDepthSpec,
	Specs.HasValidTagsSpec,
	Specs.HasValidMatcherListsSpec,
	Specs.HasValidInstanceFiltersSpec,
	Specs.HasValidAttributesSpec,
	Specs.HasValidPredicateSpec,
})

local function _CloneStringArray(values: { string }?): { string }?
	if values == nil then
		return nil
	end

	return table.clone(values)
end

local function _CloneAttributes(attributes: { [string]: any }?): { [string]: any }?
	if attributes == nil then
		return nil
	end

	return table.clone(attributes)
end

local function _CloneInstances(instances: { Instance }?): { Instance }?
	if instances == nil then
		return nil
	end

	return table.clone(instances)
end

local function _RaiseValidationFailure(result: any)
	error(result.message, 3)
end

function Policies.AssertValidOptions(options: TSearchOptions)
	assert(type(options) == "table", Enums.ErrorMessage[Enums.ErrorKey.InvalidOptions])

	for _, spec in VALIDATION_SPECS do
		local result = spec:IsSatisfiedBy(options)
		if not result.success then
			_RaiseValidationFailure(result)
		end
	end
end

function Policies.ResolveMode(options: TSearchOptions): TResolvedSearchMode
	if Specs.IsSelectorRequest(options) then
		return Enums.SearchMode.Selector
	end

	if Specs.IsPathRequest(options) then
		return Enums.SearchMode.Path
	end

	return Enums.SearchMode.Filter
end

function Policies.ResolveOptions(root: Instance, options: TSearchOptions): TResolvedSearchOptions
	Policies.AssertValidOptions(options)

	local resolvedOptions: TResolvedSearchOptions = {
		Mode = Policies.ResolveMode(options),
		Root = root,
		Selector = options.Selector,
		Path = _CloneStringArray(options.Path),
		ScopePath = _CloneStringArray(options.ScopePath),
		ScopeSelector = options.ScopeSelector,
		ScopeRecursive = options.ScopeRecursive == true,
		ScopeMaxDepth = options.ScopeMaxDepth,
		IncludeScopeRoot = options.IncludeScopeRoot == true,
		Recursive = options.Recursive == true,
		MaxDepth = options.MaxDepth,
		IncludeRoot = options.IncludeRoot == true,
		Name = options.Name,
		Names = _CloneStringArray(options.Names),
		CaseInsensitiveName = options.CaseInsensitiveName == true,
		ClassName = options.ClassName,
		ClassNames = _CloneStringArray(options.ClassNames),
		IsA = options.IsA,
		IsAAny = _CloneStringArray(options.IsAAny),
		Attributes = _CloneAttributes(options.Attributes),
		Tags = _CloneStringArray(options.Tags),
		TagsAny = _CloneStringArray(options.TagsAny),
		Instances = _CloneInstances(options.Instances),
		ExcludeInstances = _CloneInstances(options.ExcludeInstances),
		AncestorOf = options.AncestorOf,
		DescendantOf = options.DescendantOf,
		Predicate = options.Predicate,
		ExcludeAttributes = _CloneAttributes(options.ExcludeAttributes),
		ExcludeTags = _CloneStringArray(options.ExcludeTags),
		ExcludePredicate = options.ExcludePredicate,
	}

	return table.freeze(resolvedOptions)
end

return table.freeze(Policies)
