--!strict

--[[
	RemoveItemPolicy — Domain Policy

	Answers: can this slot's item be removed in the given quantity?

	RESPONSIBILITIES:
	  1. Fetch the current inventory state from InventorySyncService
	  2. Build a TRemoveItemCandidate from the passed params + state
	  3. Evaluate the CanRemoveItem spec against the candidate
	  4. Return Ok({ InventoryState, Slot }) on success to avoid re-fetching in the command

	RESULT:
	  Ok({ InventoryState, Slot }) — removal valid; state and slot returned for command use
	  Err(...)                     — inventory not found, invalid slot, slot empty, or insufficient quantity

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.RemoveItemPolicy:Check(userId, slotIndex, quantity))
	  local slot = ctx.Slot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventorySpecs = require(script.Parent.Parent.Specs.InventorySpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
    @class RemoveItemPolicy
    Domain policy that checks whether an item can be removed from a specific inventory slot.
    @server
]=]
local RemoveItemPolicy = {}
RemoveItemPolicy.__index = RemoveItemPolicy

--[=[
    @type TRemoveItemPolicy typeof(setmetatable({}, RemoveItemPolicy))
    @within RemoveItemPolicy
]=]
export type TRemoveItemPolicy = typeof(setmetatable({}, RemoveItemPolicy))

--[=[
    Create a new RemoveItemPolicy instance.
    @within RemoveItemPolicy
    @return TRemoveItemPolicy
]=]
function RemoveItemPolicy.new(): TRemoveItemPolicy
	return setmetatable({}, RemoveItemPolicy)
end

function RemoveItemPolicy:Init(registry: any)
	self.SyncService = registry:Get("InventorySyncService")
end

--[=[
    Evaluate whether the item can be removed and return the inventory state and slot data on success.
    @within RemoveItemPolicy
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot index to validate
    @param quantity number -- The quantity to remove
    @return Result<{InventoryState: any, Slot: any}> -- Ok with state and slot; Err if inventory missing, slot invalid, slot empty, or insufficient quantity
]=]
function RemoveItemPolicy:Check(
	userId: number,
	slotIndex: number,
	quantity: number
): Result.Result<{ InventoryState: any, Slot: any }>
	local inventoryState = self.SyncService:GetInventoryReadOnly(userId)
	Ensure(inventoryState, "SlotEmpty", Errors.SLOT_EMPTY)

	local totalSlots = inventoryState.Metadata.TotalSlots
	local slot = nil
	if slotIndex >= 1 and slotIndex <= totalSlots then
		slot = inventoryState.Slots[slotIndex]
	end

	local candidate: InventorySpecs.TRemoveItemCandidate = {
		SlotValid           = slotIndex >= 1 and slotIndex <= totalSlots,
		-- Defensive: passes when out of bounds — SlotValid:And short-circuits first
		SlotOccupied        = slotIndex < 1 or slotIndex > totalSlots or slot ~= nil,
		RemoveQuantityValid = quantity >= 1,
		-- Defensive: passes when slot nil — SlotOccupied already fired
		SufficientQuantity  = slot == nil or quantity <= slot.Quantity,
	}

	Try(InventorySpecs.CanRemoveItem:IsSatisfiedBy(candidate))

	return Ok({ InventoryState = inventoryState, Slot = slot })
end

return RemoveItemPolicy
