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
	Specs.HasOneRequestMode,
	Specs.HasValidPathSpec,
	Specs.HasValidMaxDepthSpec,
	Specs.HasValidTagsSpec,
	Specs.HasValidAttributesSpec,
	Specs.HasValidPredicateSpec,
})

local function _ClonePath(path: { string }?): { string }?
	if path == nil then
		return nil
	end

	return table.clone(path)
end

local function _CloneTags(tags: { string }?): { string }?
	if tags == nil then
		return nil
	end

	return table.clone(tags)
end

local function _CloneAttributes(attributes: { [string]: any }?): { [string]: any }?
	if attributes == nil then
		return nil
	end

	return table.clone(attributes)
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
		Path = _ClonePath(options.Path),
		Recursive = options.Recursive == true,
		MaxDepth = options.MaxDepth,
		Name = options.Name,
		CaseInsensitiveName = options.CaseInsensitiveName == true,
		ClassName = options.ClassName,
		IsA = options.IsA,
		Attributes = _CloneAttributes(options.Attributes),
		Tags = _CloneTags(options.Tags),
		Predicate = options.Predicate,
		ExcludeAttributes = _CloneAttributes(options.ExcludeAttributes),
		ExcludeTags = _CloneTags(options.ExcludeTags),
		ExcludePredicate = options.ExcludePredicate,
	}

	return table.freeze(resolvedOptions)
end

return table.freeze(Policies)
