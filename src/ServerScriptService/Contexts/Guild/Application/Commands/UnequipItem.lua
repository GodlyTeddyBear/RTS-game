--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class UnequipItem
	Application command that orchestrates the full unequip flow:
	validate -> return item to inventory -> clear slot -> persist.
	@server
]=]

--[=[
	@interface TUnequipResult
	@within UnequipItem
	.AdventurerId string -- The adventurer's ID
	.SlotType string -- The equipment slot type
	.ReturnedItemId string -- The item that was returned to inventory
]=]
export type TUnequipResult = {
	AdventurerId: string,
	SlotType: string,
	ReturnedItemId: string,
}

local UnequipItem = {}
UnequipItem.__index = UnequipItem

export type TUnequipItem = typeof(setmetatable({}, UnequipItem))

function UnequipItem.new(): TUnequipItem
	local self = setmetatable({}, UnequipItem)
	return self
end

--[=[
	Initialize with dependencies available at KnitInit.
	@within UnequipItem
]=]
function UnequipItem:Init(registry: any)
	self.Registry = registry
	self.UnequipPolicy = registry:Get("UnequipPolicy")
	self.GuildSyncService = registry:Get("GuildSyncService")
	self.PersistenceService = registry:Get("GuildPersistenceService")
end

--[=[
	Resolve cross-context dependencies available at KnitStart.
	@within UnequipItem
]=]
function UnequipItem:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
end

--[=[
	Execute the unequip command: validate -> return item to inventory -> clear slot -> persist.
	@within UnequipItem
	@param player Player -- The player unequipping
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@return Result<TUnequipResult> -- Adventurer ID, slot type, and returned item
	@error InvalidInput -- Player or parameters are invalid
	@error AdventurerNotFound -- Adventurer not found in roster
	@error InvalidSlotType -- Slot type is invalid
	@error SlotAlreadyEmpty -- Equipment slot is already empty
]=]
function UnequipItem:Execute(
	player: Player,
	userId: number,
	adventurerId: string,
	slotType: string
): Result.Result<TUnequipResult>
	-- Step 1: Validate inputs
	Ensure(player ~= nil and userId > 0, "InvalidInput", Errors.PLAYER_NOT_FOUND)
	Ensure(adventurerId ~= nil and slotType ~= nil, "InvalidInput", Errors.UNEQUIP_FAILED)

	-- Step 2: Evaluate unequip eligibility and fetch equipped item
	local ctx = Try(self.UnequipPolicy:Check(userId, adventurerId, slotType))
	local equippedItem = ctx.EquippedSlot
	local itemId = equippedItem.ItemId

	-- Step 3: Return item to inventory
	Try(self.InventoryContext:AddItemToInventory(userId, itemId, 1))

	-- Step 4: Clear equipment slot
	self.GuildSyncService:ClearEquipment(userId, adventurerId, slotType)

	-- Step 5: Persist to profile
	local updatedAdventurer = self.GuildSyncService:GetAdventurerReadOnly(userId, adventurerId)
	if updatedAdventurer then
		Try(self.PersistenceService:SaveAdventurer(player, adventurerId, updatedAdventurer))
	end
	MentionSuccess("Guild:UnequipItem:Execute", "Unequipped item from adventurer and persisted equipment state", {
		userId = userId,
		adventurerId = adventurerId,
		slotType = slotType,
		returnedItemId = itemId,
	})

	-- Step 6: Return result
	return Ok({
		AdventurerId = adventurerId,
		SlotType = slotType,
		ReturnedItemId = itemId,
	})
end

return UnequipItem
