--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local InventorySpecs = require(script.Parent.Parent.Specs.InventorySpecs)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local AddItemPolicy = {}
AddItemPolicy.__index = AddItemPolicy

export type TAddItemPolicy = typeof(setmetatable({}, AddItemPolicy))

function AddItemPolicy.new(): TAddItemPolicy
	return setmetatable({}, AddItemPolicy)
end

function AddItemPolicy:Init(registry: any)
	self.SyncService = registry:Get("InventorySyncService")
end

function AddItemPolicy:Check(userId: number, itemId: string, quantity: number): Result.Result<{ InventoryState: any }>
	local inventoryState = self.SyncService:GetInventoryReadOnly(userId) or {
		Slots = {},
		Metadata = { TotalSlots = 200, UsedSlots = 0, LastModified = 0 },
	}

	local itemData = ItemConfig[itemId]
	local hasAvailableStack = false
	if itemData and itemData.Stackable then
		for _, slot in pairs(inventoryState.Slots) do
			if slot.ItemId == itemId and slot.Quantity < itemData.MaxStack then
				hasAvailableStack = true
				break
			end
		end
	end

	local candidate: InventorySpecs.TAddItemCandidate = {
		ItemExists = itemData ~= nil,
		AddQuantityValid = quantity >= 1,
		InventoryNotFull = hasAvailableStack or inventoryState.Metadata.UsedSlots < inventoryState.Metadata.TotalSlots,
	}

	Try(InventorySpecs.CanAddItem:IsSatisfiedBy(candidate))

	return Ok({ InventoryState = inventoryState })
end

return AddItemPolicy
