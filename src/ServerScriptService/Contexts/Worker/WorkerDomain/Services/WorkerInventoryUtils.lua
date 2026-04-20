--!strict

--[[
	WorkerInventoryUtils — shared inventory query helpers for Worker domain policies.

	Previously duplicated across ForgeTickPolicy, BreweryTickPolicy, and TailorTickPolicy.
	Centralised here so a single fix covers all policies.
]]

local WorkerInventoryUtils = {}

--- Sum the total quantity of a specific item across all inventory slots.
function WorkerInventoryUtils.GetTotalQuantity(inventoryState: any, itemId: string): number
	if not inventoryState or not inventoryState.Slots then return 0 end
	local total = 0
	for _, slot in inventoryState.Slots do
		if slot.ItemId == itemId then
			total += slot.Quantity
		end
	end
	return total
end

--- Return true only if every entry in `materials` is present in sufficient quantity.
--- Works for both ingredient lists (Forge/Brewery/Tailor) and material lists (rank/masterpiece).
function WorkerInventoryUtils.HasMaterials(inventoryState: any, materials: { any }): boolean
	for _, mat in materials do
		if WorkerInventoryUtils.GetTotalQuantity(inventoryState, mat.ItemId) < mat.Quantity then
			return false
		end
	end
	return true
end

return WorkerInventoryUtils
