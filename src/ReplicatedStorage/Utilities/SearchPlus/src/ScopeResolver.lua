--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Find = require(ReplicatedStorage.Utilities.Find)
local Query = require(ReplicatedStorage.Utilities.Query)
local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local ScopeResolver = {}

local function _TryFindScope(root: Instance, path: { string }): Instance?
	local ok, instance = pcall(function()
		return Find(root, table.unpack(path))
	end)

	if ok then
		return instance
	end

	return nil
end

local function _GetDepth(root: Instance, instance: Instance): number?
	local depth = 0
	local current = instance

	while current ~= root do
		local parent = current.Parent
		if parent == nil then
			return nil
		end

		current = parent
		depth += 1
	end

	return depth
end

local function _ResolveScopeSelector(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	local matches = Query.all(root, resolvedOptions.ScopeSelector :: string)
	if resolvedOptions.ScopeRecursive then
		if resolvedOptions.ScopeMaxDepth == nil then
			return matches
		end

		local filteredMatches = {}
		for _, instance in matches do
			local depth = _GetDepth(root, instance)
			if depth ~= nil and depth <= (resolvedOptions.ScopeMaxDepth :: number) then
				filteredMatches[#filteredMatches + 1] = instance
			end
		end

		return filteredMatches
	end

	local filteredMatches = {}
	for _, instance in matches do
		if instance.Parent == root then
			filteredMatches[#filteredMatches + 1] = instance
		end
	end

	return filteredMatches
end

function ScopeResolver.HasScope(resolvedOptions: TResolvedSearchOptions): boolean
	return resolvedOptions.ScopePath ~= nil or resolvedOptions.ScopeSelector ~= nil
end

function ScopeResolver.Resolve(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	if resolvedOptions.ScopePath ~= nil then
		local instance = _TryFindScope(root, resolvedOptions.ScopePath :: { string })
		if instance == nil then
			return {}
		end

		return { instance }
	end

	if resolvedOptions.ScopeSelector ~= nil then
		return _ResolveScopeSelector(root, resolvedOptions)
	end

	return { root }
end

return table.freeze(ScopeResolver)
