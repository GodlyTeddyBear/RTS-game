--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local PersistInventory = require(script.Parent.Parent.PersistInventory)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
    @class ClearInventory
    Application command that removes all items from a player's inventory.
    @server
]=]
local ClearInventory = {}
ClearInventory.__index = ClearInventory

--[=[
    Create a new ClearInventory instance (zero-arg for Registry).
    @within ClearInventory
    @return ClearInventory
]=]
function ClearInventory.new()
	local self = setmetatable({}, ClearInventory)
	return self
end

--- Pulls dependencies from the Registry
function ClearInventory:Init(registry: any, _name: string)
	self.SyncService = registry:Get("InventorySyncService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
end

--[=[
    Clear all items from a player's inventory and persist the result.
    @within ClearInventory
    @param player Player -- The player whose inventory is cleared
    @param userId number -- The player's UserId
    @return Result<any> -- Ok with a confirmation message; Err if player/userId invalid or inventory not found
]=]
function ClearInventory:Execute(player: Player, userId: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidArgument", "Invalid player or userId")
	Ensure(self.SyncService:GetInventoryReadOnly(userId) ~= nil, "InventoryNotFound", "Inventory not found")

	MentionSuccess("Inventory:ClearInventory:Validation", "userId: " .. userId .. " - Starting inventory clear")

	-- Clear all slots and reset used slot count; metadata TotalSlots is preserved
	self.SyncService:ClearAllSlots(userId)
	self.SyncService:UpdateMetadata(userId, {
		UsedSlots = 0,
		LastModified = os.time(),
	})

	MentionSuccess("Inventory:ClearInventory:SlotManagement", "userId: " .. userId .. " - Inventory cleared")

	PersistInventory(self.SyncService, self.PersistenceService, player, userId)

	MentionSuccess("Inventory:ClearInventory:Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

	return Ok({
		Message = "Inventory cleared successfully",
	})
end

return ClearInventory
