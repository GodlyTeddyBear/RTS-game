--!strict

local Enums = require(script.Enums)
local FilterSearch = require(script.FilterSearch)
local PathSearch = require(script.PathSearch)
local Policies = require(script.Policies)
local SelectorSearch = require(script.SelectorSearch)
local ScopeResolver = require(script.ScopeResolver)
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

local function _CollectScopedMatches(searchModule, scopeRoots: { Instance }, resolvedOptions: TResolvedSearchOptions): { Instance }
	local seen = {}
	local matches = {}

	for _, scopeRoot in scopeRoots do
		local scopeMatches = searchModule.FindAll(scopeRoot, resolvedOptions)
		for _, instance in scopeMatches do
			if not seen[instance] then
				seen[instance] = true
				matches[#matches + 1] = instance
			end
		end
	end

	return matches
end

function SearchPlus.FindFirst(root: Instance, options: TSearchOptions): Instance?
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	if not ScopeResolver.HasScope(resolvedOptions) then
		return searchModule.FindFirst(root, resolvedOptions)
	end

	return _CollectScopedMatches(searchModule, ScopeResolver.Resolve(root, resolvedOptions), resolvedOptions)[1]
end

function SearchPlus.FindAll(root: Instance, options: TSearchOptions): { Instance }
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	if not ScopeResolver.HasScope(resolvedOptions) then
		return searchModule.FindAll(root, resolvedOptions)
	end

	return _CollectScopedMatches(searchModule, ScopeResolver.Resolve(root, resolvedOptions), resolvedOptions)
end

function SearchPlus.FindOne(root: Instance, options: TSearchOptions): Instance
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	if not ScopeResolver.HasScope(resolvedOptions) then
		return searchModule.FindOne(root, resolvedOptions)
	end

	local matches = _CollectScopedMatches(searchModule, ScopeResolver.Resolve(root, resolvedOptions), resolvedOptions)
	if #matches == 0 then
		error(Enums.ErrorMessage[Enums.ErrorKey.FindOneNoMatches], 2)
	end

	if #matches > 1 then
		error(Enums.ErrorMessage[Enums.ErrorKey.FindOneMultipleMatches], 2)
	end

	return matches[1]
end

function SearchPlus.TryFindOne(root: Instance, options: TSearchOptions): Instance?
	local searchModule, resolvedOptions = _ResolveSearch(root, options)
	local matches: { Instance }

	if ScopeResolver.HasScope(resolvedOptions) then
		matches = _CollectScopedMatches(searchModule, ScopeResolver.Resolve(root, resolvedOptions), resolvedOptions)
	else
		matches = searchModule.FindAll(root, resolvedOptions)
	end

	if #matches == 1 then
		return matches[1]
	end

	return nil
end

function SearchPlus.Exists(root: Instance, options: TSearchOptions): boolean
	return SearchPlus.FindFirst(root, options) ~= nil
end

function SearchPlus.Count(root: Instance, options: TSearchOptions): number
	return #SearchPlus.FindAll(root, options)
end

return table.freeze(SearchPlus)
