--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Query = require(ReplicatedStorage.Utilities.Query)
local Matchers = require(script.Parent.Matchers)
local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local SelectorSearch = {}

local function _CollectMatches(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	local matches = Query.all(root, resolvedOptions.Selector :: string)
	local filteredMatches = {}

	for _, instance in matches do
		if Matchers.Matches(instance, resolvedOptions) then
			filteredMatches[#filteredMatches + 1] = instance
		end
	end

	return filteredMatches
end

function SelectorSearch.FindFirst(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance?
	return _CollectMatches(root, resolvedOptions)[1]
end

function SelectorSearch.FindAll(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	return _CollectMatches(root, resolvedOptions)
end

function SelectorSearch.FindOne(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance
	local matches = _CollectMatches(root, resolvedOptions)
	if #matches ~= 1 then
		error(`expected 1 instance from query; got {#matches} instances (selector: {resolvedOptions.Selector :: string})`, 2)
	end

	return matches[1]
end

return table.freeze(SelectorSearch)
