--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Find = require(ReplicatedStorage.Utilities.Find)
local Matchers = require(script.Parent.Matchers)
local Types = require(script.Parent.Types)

type TResolvedSearchOptions = Types.TResolvedSearchOptions

local PathSearch = {}

local function _TryFind(root: Instance, path: { string }): (boolean, Instance?)
	return pcall(function()
		return Find(root, table.unpack(path))
	end)
end

function PathSearch.FindFirst(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance?
	local ok, instance = _TryFind(root, resolvedOptions.Path :: { string })
	if ok and instance ~= nil and Matchers.Matches(instance, resolvedOptions) then
		return instance
	end

	return nil
end

function PathSearch.FindAll(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	local instance = PathSearch.FindFirst(root, resolvedOptions)
	if instance == nil then
		return {}
	end

	if not Matchers.Matches(instance, resolvedOptions) then
		return {}
	end

	return { instance }
end

function PathSearch.FindOne(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance
	local instance = Find(root, table.unpack(resolvedOptions.Path :: { string }))
	if not Matchers.Matches(instance, resolvedOptions) then
		error("SearchPlus expected exactly one match, got zero", 2)
	end

	return instance
end

return table.freeze(PathSearch)
