--!strict

--[[
	AddItemPolicy — Domain Policy

	Answers: can this item be added to this player's inventory?

	RESPONSIBILITIES:
	  1. Fetch the current inventory state from InventorySyncService (or use default for new players)
	  2. Build a TAddItemCandidate from the passed params + ItemConfig + CategoryConfig + state
	  3. Evaluate the CanAddItem spec against the candidate
	  4. Return Ok({ InventoryState }) on success so the command avoids a second state fetch

	RESULT:
	  Ok({ InventoryState }) — item can be added; inventory state returned for command use
	  Err(...)               — invalid item ID, invalid quantity, inventory full, or category full

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.AddItemPolicy:Check(userId, itemId, quantity))
	  local playerInventory = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)
local InventorySpecs = require(script.Parent.Parent.Specs.InventorySpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
    @class AddItemPolicy
    Domain policy that checks whether an item can be added to a player's inventory.
    @server
]=]
local AddItemPolicy = {}
AddItemPolicy.__index = AddItemPolicy

--[=[
    @type TAddItemPolicy typeof(setmetatable({}, AddItemPolicy))
    @within AddItemPolicy
]=]
export type TAddItemPolicy = typeof(setmetatable({}, AddItemPolicy))

--[=[
    Create a new AddItemPolicy instance.
    @within AddItemPolicy
    @return TAddItemPolicy
]=]
function AddItemPolicy.new(): TAddItemPolicy
	return setmetatable({}, AddItemPolicy)
end

function AddItemPolicy:Init(registry: any)
	self.SyncService = registry:Get("InventorySyncService")
end

--[=[
    Evaluate whether the item can be added and return the current inventory state on success.
    @within AddItemPolicy
    @param userId number -- The player's UserId
    @param itemId string -- The item ID to validate
    @param quantity number -- The quantity to validate
    @return Result<{InventoryState: any}> -- Ok with inventory state on success; Err if item invalid, quantity invalid, inventory full, or category full
]=]
function AddItemPolicy:Check(userId: number, itemId: string, quantity: number): Result.Result<{ InventoryState: any }>
	local inventoryState = self.SyncService:GetInventoryReadOnly(userId) or {
		Slots = {},
		Metadata = { TotalSlots = 200, UsedSlots = 0, LastModified = 0 },
	}

	local itemData = ItemConfig[itemId]
	local categoryConfig = itemData and CategoryConfig[itemData.category]
	local maxStack = (itemData and categoryConfig) and math.min(itemData.maxStack, categoryConfig.maxStack) or 1

	-- Count category usage in one pass (safe: only runs when itemData exists)
	local categoryUsed = 0
	if itemData then
		for _, slot in pairs(inventoryState.Slots) do
			if slot.Category == itemData.category then
				categoryUsed += 1
			end
		end
	end

	local candidate: InventorySpecs.TAddItemCandidate = {
		ItemExists       = itemData ~= nil,
		-- Defensive: passes when item unknown — AddItemExists:And short-circuits first
		AddQuantityValid = itemData == nil or (quantity >= 1 and quantity <= maxStack),
		InventoryNotFull = inventoryState.Metadata.UsedSlots < inventoryState.Metadata.TotalSlots,
		CategoryNotFull  = itemData == nil or categoryConfig == nil or categoryUsed < categoryConfig.totalCapacity,
	}

	Try(InventorySpecs.CanAddItem:IsSatisfiedBy(candidate))

	return Ok({ InventoryState = inventoryState })
end

return AddItemPolicy
