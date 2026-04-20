--!strict
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local GetInventory = {}
GetInventory.__index = GetInventory

--- Creates a new GetInventory service (read-only operation)
-- Constructor Injection: Receives playerInventoriesAtom dependency
function GetInventory.new(playerInventoriesAtom: any)
	local self = setmetatable({}, GetInventory)

	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Gets current inventory state for a player
-- Returns (success: boolean, inventory: any or error: string)
function GetInventory:Execute(userId: number): (boolean, any)
	if not userId or userId <= 0 then
		warn("[Inventory:GetInventory] userId:", userId, "- Invalid userId")
		return false, "Invalid userId"
	end

	local currentAtom = self.PlayerInventoriesAtom
	if not currentAtom then
		warn("[Inventory:GetInventory] userId:", userId, "- Inventory atom not initialized")
		return false, "Inventory atom not initialized"
	end

	-- Get current atom value
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId]

	if not playerInventory then
		-- Return empty inventory structure if not found
		self.DebugLogger:Log("GetInventory", "Validation", "userId: " .. userId .. " - Returning empty inventory (not found)")
		return true, {
			Slots = {},
			Metadata = {
				TotalSlots = 200,
				UsedSlots = 0,
				LastModified = 0,
			},
		}
	end

	self.DebugLogger:Log("GetInventory", "Validation", "userId: " .. userId .. " - Retrieved inventory (" .. (playerInventory.Metadata.UsedSlots or 0) .. " slots used)")
	return true, playerInventory
end

return GetInventory
