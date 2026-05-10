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

local function _ResolveSearch(root: Instance, options: TSearchOptions)
	_AssertRoot(root)
	local resolvedOptions = Policies.ResolveOptions(root, options)
	local searchModule = _ResolveSearchModule(resolvedOptions.Mode)
	return searchModule, resolvedOptions
end

function SearchPlus.FindFirst(root: Instance, options: TSearchOptions): Instance?
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	return searchModule.FindFirst(root, resolvedOptions)
end

function SearchPlus.FindAll(root: Instance, options: TSearchOptions): { Instance }
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	return searchModule.FindAll(root, resolvedOptions)
end

function SearchPlus.FindOne(root: Instance, options: TSearchOptions): Instance
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	return searchModule.FindOne(root, resolvedOptions)
end

function SearchPlus.TryFindOne(root: Instance, options: TSearchOptions): Instance?
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	local matches = searchModule.FindAll(root, resolvedOptions)
	if #matches == 1 then
		return matches[1]
	end

	return nil
end

function SearchPlus.Exists(root: Instance, options: TSearchOptions): boolean
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	return searchModule.FindFirst(root, resolvedOptions) ~= nil
end

function SearchPlus.Count(root: Instance, options: TSearchOptions): number
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	return #searchModule.FindAll(root, resolvedOptions)
end

return table.freeze(SearchPlus)
