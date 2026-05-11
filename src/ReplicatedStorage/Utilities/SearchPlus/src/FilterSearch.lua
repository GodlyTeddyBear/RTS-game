--!strict

local Enums = require(script.Parent.Enums)
local Matchers = require(script.Parent.Matchers)
local Traversal = require(script.Parent.Traversal)
local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local FilterSearch = {}

local function _Matches(resolvedOptions: TResolvedSearchOptions, instance: Instance): boolean
	return Matchers.Matches(instance, resolvedOptions)
end

local function _ShouldIncludeRoot(resolvedOptions: TResolvedSearchOptions): boolean
	if resolvedOptions.ScopePath ~= nil or resolvedOptions.ScopeSelector ~= nil then
		return resolvedOptions.IncludeScopeRoot
	end

	return resolvedOptions.IncludeRoot
end

function FilterSearch.FindFirst(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance?
	if _ShouldIncludeRoot(resolvedOptions) and _Matches(resolvedOptions, root) then
		return root
	end

	if resolvedOptions.Recursive then
		return Traversal.FindFirst(root, resolvedOptions.MaxDepth, function(instance: Instance)
			return _Matches(resolvedOptions, instance)
		end)
	end

	for _, child in Traversal.GetChildren(root) do
		if _Matches(resolvedOptions, child) then
			return child
		end
	end

	return nil
end

function FilterSearch.FindAll(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	local matches = {}

	if _ShouldIncludeRoot(resolvedOptions) and _Matches(resolvedOptions, root) then
		matches[#matches + 1] = root
	end

	if resolvedOptions.Recursive then
		local descendantMatches = Traversal.CollectAll(root, resolvedOptions.MaxDepth, function(instance: Instance)
			return _Matches(resolvedOptions, instance)
		end)
		for _, instance in descendantMatches do
			matches[#matches + 1] = instance
		end

		return matches
	end

	for _, child in Traversal.GetChildren(root) do
		if _Matches(resolvedOptions, child) then
			matches[#matches + 1] = child
		end
	end

	return matches
end

function FilterSearch.FindOne(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance
	local matches = FilterSearch.FindAll(root, resolvedOptions)
	if #matches == 0 then
		error(Enums.ErrorMessage[Enums.ErrorKey.FindOneNoMatches], 2)
	end

	if #matches > 1 then
		error(Enums.ErrorMessage[Enums.ErrorKey.FindOneMultipleMatches], 2)
	end

	return matches[1]
end

return table.freeze(FilterSearch)
