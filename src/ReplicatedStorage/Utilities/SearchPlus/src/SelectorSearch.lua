--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Query = require(ReplicatedStorage.Utilities.Query)
local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local SelectorSearch = {}

function SelectorSearch.FindFirst(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance?
	return Query.first(root, resolvedOptions.Selector :: string)
end

function SelectorSearch.FindAll(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	return Query.all(root, resolvedOptions.Selector :: string)
end

function SelectorSearch.FindOne(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance
	return Query.one(root, resolvedOptions.Selector :: string)
end

return table.freeze(SelectorSearch)
