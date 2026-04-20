--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

local CapacityService = {}
CapacityService.__index = CapacityService

--- Creates a new CapacityService (no dependencies - pure domain logic)
function CapacityService.new()
	local self = setmetatable({}, CapacityService)
	return self
end

--- Gets the number of slots used in a specific category
function CapacityService:GetCategoryUsage(inventoryState: any, category: string): number
	local used = 0

	for _, slot in pairs(inventoryState.Slots) do
		if slot.Category == category then
			used = used + 1
		end
	end

	return used
end

--- Gets available slots in a specific category
function CapacityService:GetCategoryAvailable(inventoryState: any, category: string): number
	local categoryConfig = CategoryConfig[category]
	if not categoryConfig then
		return 0
	end

	local used = self:GetCategoryUsage(inventoryState, category)
	return math.max(0, categoryConfig.totalCapacity - used)
end

--- Checks if adding N items to a category would fit
function CapacityService:CanAddToCategory(inventoryState: any, category: string, count: number): boolean
	if count <= 0 then
		return false
	end

	local available = self:GetCategoryAvailable(inventoryState, category)
	return count <= available
end

--- Gets total inventory usage
function CapacityService:GetTotalUsage(inventoryState: any): number
	local total = 0

	for _ in pairs(inventoryState.Slots) do
		total = total + 1
	end

	return total
end

--- Gets total available slots in inventory
function CapacityService:GetTotalAvailable(inventoryState: any): number
	local total = inventoryState.Metadata.TotalSlots or 200
	local used = self:GetTotalUsage(inventoryState)
	return math.max(0, total - used)
end

--- Checks if inventory is full
function CapacityService:IsInventoryFull(inventoryState: any): boolean
	return self:GetTotalAvailable(inventoryState) <= 0
end

--- Gets usage statistics for all categories
function CapacityService:GetCategoryStats(inventoryState: any): { [string]: { Used: number, Max: number, Available: number } }
	local stats = {}

	for categoryName, categoryConfig in pairs(CategoryConfig) do
		local used = self:GetCategoryUsage(inventoryState, categoryName)
		local available = self:GetCategoryAvailable(inventoryState, categoryName)

		stats[categoryName] = {
			Used = used,
			Max = categoryConfig.totalCapacity,
			Available = available,
		}
	end

	return stats
end

return CapacityService
