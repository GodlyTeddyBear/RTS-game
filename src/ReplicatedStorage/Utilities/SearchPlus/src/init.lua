--!strict

local Enums = require(script.Enums)
local FilterSearch = require(script.FilterSearch)
local PathSearch = require(script.PathSearch)
local Policies = require(script.Policies)
local SelectorSearch = require(script.SelectorSearch)
local Types = require(script.Types)

export type TSearchOptions = Types.TSearchOptions
export type TResolvedSearchMode = Types.TResolvedSearchMode
export type TResolvedSearchOptions = Types.TResolvedSearchOptions

--[=[
	@class SearchPlusPackage
	Structured package surface for `SearchPlus` hierarchy-search helpers.
	@server
	@client
]=]
local SearchPlus = {
	SearchMode = Enums.SearchMode,
}

local function _AssertRoot(root: Instance)
	assert(typeof(root) == "Instance", Enums.ErrorMessage[Enums.ErrorKey.InvalidRoot])
end

local function _ResolveSearchModule(mode: TResolvedSearchMode)
	if mode == Enums.SearchMode.Selector then
		return SelectorSearch
	end

	if mode == Enums.SearchMode.Path then
		return PathSearch
	end

	return FilterSearch
end

function SearchPlus.FindFirst(root: Instance, options: TSearchOptions): Instance?
	_AssertRoot(root)
	local resolvedOptions = Policies.ResolveOptions(root, options)
	local searchModule = _ResolveSearchModule(resolvedOptions.Mode)
	return searchModule.FindFirst(root, resolvedOptions)
end

function SearchPlus.FindAll(root: Instance, options: TSearchOptions): { Instance }
	_AssertRoot(root)
	local resolvedOptions = Policies.ResolveOptions(root, options)
	local searchModule = _ResolveSearchModule(resolvedOptions.Mode)
	return searchModule.FindAll(root, resolvedOptions)
end

function SearchPlus.FindOne(root: Instance, options: TSearchOptions): Instance
	_AssertRoot(root)
	local resolvedOptions = Policies.ResolveOptions(root, options)
	local searchModule = _ResolveSearchModule(resolvedOptions.Mode)
	return searchModule.FindOne(root, resolvedOptions)
end

return table.freeze(SearchPlus)
