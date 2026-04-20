--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
    @class GetInventory
    Application query that returns the current inventory state for a player.
    @server
]=]
local GetInventory = {}
GetInventory.__index = GetInventory

--[=[
    Create a new GetInventory instance (zero-arg for Registry).
    @within GetInventory
    @return GetInventory
]=]
function GetInventory.new()
	local self = setmetatable({}, GetInventory)
	return self
end

--- Pulls dependencies from the Registry
function GetInventory:Init(registry: any, _name: string)
	self.SyncService = registry:Get("InventorySyncService")
end

--[=[
    Return the current inventory state for a player, or an empty default if no inventory exists.
    @within GetInventory
    @param userId number -- The player's UserId
    @return Result<any> -- Ok with the inventory state table
]=]
function GetInventory:Execute(userId: number): Result.Result<any>
	Ensure(userId and userId > 0, "InvalidUserId", "Invalid userId", { userId = userId })

	-- Fetch inventory; SyncService returns deep clone for safe read-only access (prevents CharmSync mutations)
	local playerInventory = self.SyncService:GetInventoryReadOnly(userId)

	-- Return default empty inventory if player has no saved state yet (new player or not loaded)
	if not playerInventory then
		MentionSuccess("Inventory:GetInventory:Validation", "userId: " .. userId .. " - Returning empty inventory (not found)")
		return Ok({
			Slots = {},
			Metadata = {
				TotalSlots = 200,
				UsedSlots = 0,
				LastModified = 0,
			},
		})
	end

	-- Return cloned inventory state for querying client; includes all slot data and metadata
	MentionSuccess(
		"Inventory:GetInventory:Validation",
		"userId: " .. userId .. " - Retrieved inventory (" .. (playerInventory.Metadata.UsedSlots or 0) .. " slots used)"
	)
	return Ok(playerInventory)
end

return GetInventory
