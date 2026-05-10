--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Find = require(ReplicatedStorage.Utilities.Find)
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
	if ok then
		return instance
	end

	return nil
end

function PathSearch.FindAll(root: Instance, resolvedOptions: TResolvedSearchOptions): { Instance }
	local instance = PathSearch.FindFirst(root, resolvedOptions)
	if instance == nil then
		return {}
	end

	return { instance }
end

function PathSearch.FindOne(root: Instance, resolvedOptions: TResolvedSearchOptions): Instance
	return Find(root, table.unpack(resolvedOptions.Path :: { string }))
end

return table.freeze(PathSearch)
