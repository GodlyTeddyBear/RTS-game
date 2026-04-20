--!strict

--[[
	StackItemsPolicy — Domain Policy

	Answers: is this item valid and stackable?

	RESPONSIBILITIES:
	  1. Build a TStackItemsCandidate from the passed itemId + ItemConfig
	  2. Evaluate the CanStackItem spec against the candidate
	  3. Return Ok(nil) on success (no additional state needed by the command)

	All checks are pure config lookups — no registry dependencies needed.

	RESULT:
	  Ok(nil)  — item ID is valid and the item is stackable
	  Err(...) — invalid item ID or item is not stackable

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  Try(self.StackItemsPolicy:Check(itemId))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local InventorySpecs = require(script.Parent.Parent.Specs.InventorySpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
    @class StackItemsPolicy
    Domain policy that checks whether an item is valid and stackable before consolidation.
    @server
]=]
local StackItemsPolicy = {}
StackItemsPolicy.__index = StackItemsPolicy

--[=[
    @type TStackItemsPolicy typeof(setmetatable({}, StackItemsPolicy))
    @within StackItemsPolicy
]=]
export type TStackItemsPolicy = typeof(setmetatable({}, StackItemsPolicy))

--[=[
    Create a new StackItemsPolicy instance.
    @within StackItemsPolicy
    @return TStackItemsPolicy
]=]
function StackItemsPolicy.new(): TStackItemsPolicy
	return setmetatable({}, StackItemsPolicy)
end

--[=[
    Evaluate whether the given item exists and is stackable.
    @within StackItemsPolicy
    @param itemId string -- The item ID to validate
    @return Result<nil> -- Ok(nil) if valid and stackable; Err if item does not exist or is not stackable
]=]
function StackItemsPolicy:Check(itemId: string): Result.Result<nil>
	local itemData = ItemConfig[itemId]

	local candidate: InventorySpecs.TStackItemsCandidate = {
		ItemExists    = itemData ~= nil,
		-- Defensive: passes when item unknown — StackItemExists:And short-circuits first
		ItemStackable = itemData == nil or itemData.stackable == true,
	}

	Try(InventorySpecs.CanStackItem:IsSatisfiedBy(candidate))

	return Ok(nil)
end

return StackItemsPolicy
