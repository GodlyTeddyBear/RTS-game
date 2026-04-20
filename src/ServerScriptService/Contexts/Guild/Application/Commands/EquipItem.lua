--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class EquipItem
	Application command that orchestrates the full equip flow:
	validate -> swap old item back -> remove new from inventory -> set equipment -> persist.
	@server
]=]

--[=[
	@interface TEquipResult
	@within EquipItem
	.AdventurerId string -- The adventurer's ID
	.SlotType string -- The equipment slot type
	.ItemId string -- The equipped item's ID
	.PreviousItemId string? -- The item that was previously equipped, if any
]=]
export type TEquipResult = {
	AdventurerId: string,
	SlotType: string,
	ItemId: string,
	PreviousItemId: string?,
}

local EquipItem = {}
EquipItem.__index = EquipItem

export type TEquipItem = typeof(setmetatable({}, EquipItem))

function EquipItem.new(): TEquipItem
	local self = setmetatable({}, EquipItem)
	return self
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within EquipItem
]=]
function EquipItem:Init(registry: any)
	self.Registry = registry
	self.EquipPolicy = registry:Get("EquipPolicy")
	self.GuildSyncService = registry:Get("GuildSyncService")
	self.PersistenceService = registry:Get("GuildPersistenceService")
end

--[=[
	Resolve cross-context dependencies available at KnitStart.
	@within EquipItem
]=]
function EquipItem:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
end

--[=[
	Execute the equip command: validate -> swap old item -> remove new -> set equipment -> persist.
	@within EquipItem
	@param player Player -- The player equipping
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@param inventorySlotIndex number -- Inventory slot index
	@return Result<TEquipResult> -- Adventurer ID, slot type, new item, and previous item if any
	@error InvalidInput -- Player or parameters are invalid
	@error AdventurerNotFound -- Adventurer not found in roster
	@error InvalidSlotType -- Slot type is invalid
	@error ItemNotInInventory -- Inventory slot is empty
	@error ItemNotEquippable -- Item category cannot be equipped in this slot
]=]
function EquipItem:Execute(
	player: Player,
	userId: number,
	adventurerId: string,
	slotType: string,
	inventorySlotIndex: number
): Result.Result<TEquipResult>
	-- Step 1: Validate inputs
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)
	Ensure(adventurerId ~= nil and slotType ~= nil and inventorySlotIndex ~= nil, "InvalidInput", Errors.EQUIP_FAILED)

	-- Step 2: Evaluate equip eligibility and fetch state
	local ctx = Try(self.EquipPolicy:Check(userId, adventurerId, slotType, inventorySlotIndex))
	local adventurers = ctx.Adventurers
	local inventorySlot = ctx.InventorySlot
	local itemId = inventorySlot.ItemId

	-- Step 3: Get current equipment and previous item if equipped
	local adventurer = adventurers[adventurerId]
	local oldEquipment = adventurer.Equipment[slotType]

	-- Step 4: Return old item to inventory if slot was occupied
	-- (must do this before removing new item, so inventory doesn't overflow)
	if oldEquipment then
		Try(self.InventoryContext:AddItemToInventory(userId, oldEquipment.ItemId, 1))
	end

	-- Step 5: Remove new item from inventory
	Try(self.InventoryContext:RemoveItemFromInventory(userId, inventorySlotIndex, 1))

	-- Step 6: Set equipment on adventurer
	self.GuildSyncService:SetEquipment(userId, adventurerId, slotType, {
		ItemId = itemId,
		SlotType = slotType,
	})

	-- Step 7: Persist to profile
	local updatedAdventurer = self.GuildSyncService:GetAdventurerReadOnly(userId, adventurerId)
	if updatedAdventurer then
		Try(self.PersistenceService:SaveAdventurer(player, adventurerId, updatedAdventurer))
	end
	MentionSuccess("Guild:EquipItem:Execute", "Equipped item on adventurer and persisted equipment state", {
		userId = userId,
		adventurerId = adventurerId,
		slotType = slotType,
		itemId = itemId,
	})

	-- Step 8: Return result
	return Ok({
		AdventurerId = adventurerId,
		SlotType = slotType,
		ItemId = itemId,
		PreviousItemId = oldEquipment and oldEquipment.ItemId or nil,
	})
end

return EquipItem
