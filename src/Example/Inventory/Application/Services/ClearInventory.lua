--!strict
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local ClearInventory = {}
ClearInventory.__index = ClearInventory

--- Creates a new ClearInventory service (admin/testing)
-- Constructor Injection: Receives required dependencies
function ClearInventory.new(playerInventoriesAtom: any, persistenceService: any)
	local self = setmetatable({}, ClearInventory)

	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Clears all items from a player's inventory (admin/testing only)
-- Returns (success: boolean, data/error: any)
function ClearInventory:Execute(player: Player, userId: number): (boolean, any)
	if not player or userId <= 0 then
		warn("[Inventory:ClearInventory] userId:", userId, "- Invalid player or userId")
		return false, "Invalid player or userId"
	end

	-- Get current inventory
	local currentAtom = self.PlayerInventoriesAtom
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId]

	if not playerInventory then
		warn("[Inventory:ClearInventory] userId:", userId, "- Inventory not found")
		return false, "Inventory not found"
	end

	self.DebugLogger:Log("ClearInventory", "Validation", "userId: " .. userId .. " - Starting inventory clear")

	-- Clear all slots
	playerInventory.Slots = {}
	playerInventory.Metadata.UsedSlots = 0
	playerInventory.Metadata.LastModified = os.time()

	-- Update atom atomically
	local success = false
	(currentAtom :: any)(function(current)
		local updated = table.clone(current)
		updated[userId] = playerInventory
		success = true
		return updated
	end)

	if success then
		self.DebugLogger:Log("ClearInventory", "SlotManagement", "userId: " .. userId .. " - Inventory cleared")

		-- Persist to ProfileStore
		local persistSuccess = self.PersistenceService:SaveInventory(player, playerInventory)
		if not persistSuccess then
			warn("[Inventory:ClearInventory] userId:", userId, "- Failed to persist inventory")
			return false, "Failed to persist inventory"
		end

		self.DebugLogger:Log("ClearInventory", "Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

		return true, {
			Message = "Inventory cleared successfully",
		}
	end

	warn("[Inventory:ClearInventory] userId:", userId, "- Failed to update inventory atom")
	return false, "Failed to update inventory atom"
end

return ClearInventory
