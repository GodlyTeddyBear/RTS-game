--!strict

--[=[
	@class EquipPolicy
	Domain policy that answers: can this item be equipped to this adventurer in this slot?
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local GuildSpecs = require(script.Parent.Parent.Specs.GuildSpecs)
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

-- Maps item category to the equipment slot type it can occupy
local CATEGORY_TO_SLOT: { [string]: string } = {
	Weapon    = "Weapon",
	Armor     = "Armor",
	Accessory = "Accessory",
}

local VALID_SLOT_TYPES = {
	Weapon    = true,
	Armor     = true,
	Accessory = true,
}

local EquipPolicy = {}
EquipPolicy.__index = EquipPolicy

export type TEquipPolicy = typeof(setmetatable({}, EquipPolicy))

function EquipPolicy.new(): TEquipPolicy
	return setmetatable({}, EquipPolicy)
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within EquipPolicy
]=]
function EquipPolicy:Init(registry: any)
	self._registry = registry
	self.GuildSyncService = registry:Get("GuildSyncService")
end

--[=[
	Resolve cross-context dependencies available at KnitStart.
	@within EquipPolicy
]=]
function EquipPolicy:Start()
	self.InventoryContext = self._registry:Get("InventoryContext")
end

--[=[
	Evaluate whether an item can be equipped to an adventurer in a given slot.
	Fetches adventurer and inventory state, builds candidate, and evaluates specs.
	@within EquipPolicy
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@param inventorySlotIndex number -- Inventory slot index (1-based)
	@return Result<{Adventurers: any, InventorySlot: any}> -- Roster and inventory slot for command use
	@error AdventurerNotFound -- Adventurer ID not found in roster
	@error InvalidSlotType -- Slot type is not valid
	@error ItemNotInInventory -- Inventory slot is empty or out of bounds
	@error ItemNotEquippable -- Item category cannot be equipped in this slot
]=]
function EquipPolicy:Check(
	userId: number,
	adventurerId: string,
	slotType: string,
	inventorySlotIndex: number
): Result.Result<{ Adventurers: any, InventorySlot: any }>
	-- Step 1: Fetch current roster and inventory state
	local adventurers = self.GuildSyncService:GetAdventurersReadOnly(userId)
	Ensure(adventurers ~= nil, "AdventurerNotFound", Errors.ADVENTURER_NOT_FOUND)

	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))
	local inventorySlot = inventoryState.Slots[inventorySlotIndex]

	-- Step 2: Pre-compute equippability (defensive: nil when slot/itemData absent)
	local itemData = inventorySlot and ItemConfig[inventorySlot.ItemId]
	local slotIsValid = VALID_SLOT_TYPES[slotType] == true

	-- Step 3: Build candidate for spec evaluation
	-- Defensive specs pass when prerequisite is false, so only root error is reported
	local candidate: GuildSpecs.TEquipItemCandidate = {
		AdventurerExists       = adventurers[adventurerId] ~= nil,
		SlotTypeValid          = adventurers[adventurerId] == nil or slotIsValid,
		InventorySlotOccupied  = adventurers[adventurerId] == nil or inventorySlot ~= nil,
		ItemEquippable         = inventorySlot == nil
			or not slotIsValid
			or (itemData ~= nil and CATEGORY_TO_SLOT[itemData.category] == slotType),
	}

	-- Step 4: Evaluate composite spec (short-circuits on missing adventurer)
	Try(GuildSpecs.CanEquipItem:IsSatisfiedBy(candidate))

	-- Step 5: Return state for command to use
	return Ok({ Adventurers = adventurers, InventorySlot = inventorySlot })
end

return EquipPolicy
