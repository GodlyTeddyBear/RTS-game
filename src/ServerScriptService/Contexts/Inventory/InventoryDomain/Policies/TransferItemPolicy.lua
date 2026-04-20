--!strict

--[[
	TransferItemPolicy — Domain Policy

	Answers: can an item be transferred between these two slots?

	RESPONSIBILITIES:
	  1. Fetch the current inventory state from InventorySyncService
	  2. Build a TTransferItemCandidate from the passed params + state
	  3. Evaluate the CanTransferItem spec against the candidate
	  4. Return Ok({ InventoryState }) on success to avoid re-fetching in the command

	RESULT:
	  Ok({ InventoryState }) — transfer valid; inventory state returned for command use
	  Err(...)               — inventory not found, same slot, invalid slot index, or source slot empty

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.TransferItemPolicy:Check(userId, fromSlot, toSlot))
	  local playerInventory = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventorySpecs = require(script.Parent.Parent.Specs.InventorySpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

--[=[
    @class TransferItemPolicy
    Domain policy that checks whether an item can be transferred between two inventory slots.
    @server
]=]
local TransferItemPolicy = {}
TransferItemPolicy.__index = TransferItemPolicy

--[=[
    @type TTransferItemPolicy typeof(setmetatable({}, TransferItemPolicy))
    @within TransferItemPolicy
]=]
export type TTransferItemPolicy = typeof(setmetatable({}, TransferItemPolicy))

--[=[
    Create a new TransferItemPolicy instance.
    @within TransferItemPolicy
    @return TTransferItemPolicy
]=]
function TransferItemPolicy.new(): TTransferItemPolicy
	return setmetatable({}, TransferItemPolicy)
end

function TransferItemPolicy:Init(registry: any)
	self.SyncService = registry:Get("InventorySyncService")
end

--[=[
    Evaluate whether an item can be transferred and return the inventory state on success.
    @within TransferItemPolicy
    @param userId number -- The player's UserId
    @param fromSlot number -- Source slot index
    @param toSlot number -- Destination slot index
    @return Result<{InventoryState: any}> -- Ok with inventory state; Err if inventory missing, same slot, invalid slot, or source slot empty
]=]
function TransferItemPolicy:Check(
	userId: number,
	fromSlot: number,
	toSlot: number
): Result.Result<{ InventoryState: any }>
	local inventoryState = self.SyncService:GetInventoryReadOnly(userId)
	Ensure(inventoryState ~= nil, "SlotEmpty", Errors.SLOT_EMPTY)

	local totalSlots = inventoryState.Metadata.TotalSlots
	local fromSlotData = nil
	if fromSlot >= 1 and fromSlot <= totalSlots then
		fromSlotData = inventoryState.Slots[fromSlot]
	end

	local candidate: InventorySpecs.TTransferItemCandidate = {
		NotSameSlot      = fromSlot ~= toSlot,
		FromSlotValid    = fromSlot >= 1 and fromSlot <= totalSlots,
		-- Defensive: passes when out of bounds — FromSlotValid:And short-circuits first
		FromSlotOccupied = fromSlot < 1 or fromSlot > totalSlots or fromSlotData ~= nil,
		ToSlotValid      = toSlot >= 1 and toSlot <= totalSlots,
	}

	Try(InventorySpecs.CanTransferItem:IsSatisfiedBy(candidate))

	return Ok({ InventoryState = inventoryState })
end

return TransferItemPolicy
