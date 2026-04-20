--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

--[=[
    @class CapacityService
    Pure domain service for querying and checking inventory capacity by slot and category.
    @server
]=]
local CapacityService = {}
CapacityService.__index = CapacityService

--[=[
    Create a new CapacityService with no dependencies.
    @within CapacityService
    @return CapacityService
]=]
function CapacityService.new()
	local self = setmetatable({}, CapacityService)
	return self
end

--[=[
    Count how many occupied slots belong to the given category.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @param category string -- The category name to count
    @return number -- Number of occupied slots in that category
]=]
function CapacityService:GetCategoryUsage(inventoryState: any, category: string): number
	local used = 0

	for _, slot in pairs(inventoryState.Slots) do
		if slot.Category == category then
			used = used + 1
		end
	end

	return used
end

--[=[
    Return the number of remaining slots available in the given category.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @param category string -- The category name to check
    @return number -- Available slots (0 if category config is missing)
]=]
function CapacityService:GetCategoryAvailable(inventoryState: any, category: string): number
	local categoryConfig = CategoryConfig[category]
	if not categoryConfig then
		return 0
	end

	local used = self:GetCategoryUsage(inventoryState, category)
	return math.max(0, categoryConfig.totalCapacity - used)
end

--[=[
    Check whether `count` new slots can be added to the given category without exceeding its limit.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @param category string -- The category name to check
    @param count number -- How many slots to add
    @return boolean -- True if the slots fit; false if count <= 0 or category is full
]=]
function CapacityService:CanAddToCategory(inventoryState: any, category: string, count: number): boolean
	if count <= 0 then
		return false
	end

	local available = self:GetCategoryAvailable(inventoryState, category)
	return count <= available
end

--[=[
    Return the total number of occupied slots across the entire inventory.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @return number -- Count of occupied slots
]=]
function CapacityService:GetTotalUsage(inventoryState: any): number
	local total = 0

	for _ in pairs(inventoryState.Slots) do
		total = total + 1
	end

	return total
end

--[=[
    Return the number of empty slots remaining in the entire inventory.
    @within CapacityService
    @param inventoryState any -- The current inventory state (uses `Metadata.TotalSlots`, default 200)
    @return number -- Available slots (clamped to 0)
]=]
function CapacityService:GetTotalAvailable(inventoryState: any): number
	local total = inventoryState.Metadata.TotalSlots or 200
	local used = self:GetTotalUsage(inventoryState)
	return math.max(0, total - used)
end

--[=[
    Check whether every slot in the inventory is occupied.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @return boolean -- True if no empty slots remain
]=]
function CapacityService:IsInventoryFull(inventoryState: any): boolean
	return self:GetTotalAvailable(inventoryState) <= 0
end

--[=[
    Return usage statistics for every category defined in CategoryConfig.
    @within CapacityService
    @param inventoryState any -- The current inventory state
    @return {[string]: {Used: number, Max: number, Available: number}} -- Per-category slot usage
]=]
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
