--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
    @class InventoryPersistenceService
    Infrastructure service responsible for saving and loading inventory data via ProfileStore.
    @server
]=]
local InventoryPersistenceService = {}
InventoryPersistenceService.__index = InventoryPersistenceService

--[=[
    Create a new InventoryPersistenceService instance (zero-arg for Registry).
    @within InventoryPersistenceService
    @return InventoryPersistenceService
]=]
function InventoryPersistenceService.new()
	local self = setmetatable({}, InventoryPersistenceService)
	return self
end

--- Pulls dependencies from the Registry
function InventoryPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

--[=[
    Save the current inventory state to the player's profile data.
    @within InventoryPersistenceService
    @param player Player -- The player whose profile is updated
    @param inventoryState any -- The inventory state table to persist
    @return Result<boolean> -- Ok(true) on success; Err if player/state missing or no profile data found
]=]
function InventoryPersistenceService:SaveInventory(player: Player, inventoryState: any): Result.Result<boolean>
	Ensure(player and inventoryState, "InvalidArgument", "Player and inventoryState are required")

	-- Fetch profile and ensure it exists; ProfileManager guarantees data availability post-load
	local data = self.ProfileManager:GetData(player)
	Ensure(data, "PersistenceFailed", "No profile data", { userId = player.UserId })

	-- Clone slots and update metadata timestamps; ProfileStore change events fire on mutation
	data.Inventory.Slots = table.clone(inventoryState.Slots)
	data.Inventory.Metadata.UsedSlots = inventoryState.Metadata.UsedSlots
	data.Inventory.Metadata.LastModified = os.time()

	return Ok(true)
end

--[=[
    Load the inventory from the player's profile data.
    @within InventoryPersistenceService
    @param player Player -- The player to load inventory for
    @return any? -- The stored inventory table, or nil if player or profile data is missing
]=]
function InventoryPersistenceService:LoadInventory(player: Player): any?
	if not player then
		return nil
	end

	local data = self.ProfileManager:GetData(player)
	if not data then
		return nil
	end
	return data.Inventory
end

--[=[
    Clear the inventory slots in the player's profile data (admin/testing only).
    @within InventoryPersistenceService
    @param player Player -- The player whose profile inventory is cleared
    @return Result<boolean> -- Ok(true) on success; Err if player missing or no profile data found
]=]
function InventoryPersistenceService:ClearInventory(player: Player): Result.Result<boolean>
	Ensure(player, "InvalidArgument", "Player is required")

	local data = self.ProfileManager:GetData(player)
	Ensure(data, "PersistenceFailed", "No profile data", { userId = player.UserId })

	data.Inventory.Slots = {}
	data.Inventory.Metadata.UsedSlots = 0
	data.Inventory.Metadata.LastModified = os.time()

	return Ok(true)
end

return InventoryPersistenceService
