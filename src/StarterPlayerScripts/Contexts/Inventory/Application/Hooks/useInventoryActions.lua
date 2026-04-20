--!strict

--[=[
	@function useInventoryActions
	@within useInventoryActions
	Write hook providing inventory mutations without atom subscriptions.
	@return TInventoryActionsAPI
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@interface TInventoryActionsAPI
	@within useInventoryActions
	.removeItem (slotIndex: number, quantity: number) -> Result<void> -- Remove items from slot
	.stackItems (itemId: string) -> Result<void> -- Stack all matching items
	.transferItem (fromSlot: number, toSlot: number) -> Result<void> -- Move item to slot
	.addItem (itemId: string, quantity: number) -> Result<void> -- Add items to inventory
]=]

local function useInventoryActions()
	local inventoryController = Knit.GetController("InventoryController")

	return {
		removeItem = function(slotIndex: number, quantity: number)
			return inventoryController:RemoveItem(slotIndex, quantity)
		end,
		stackItems = function(itemId: string)
			return inventoryController:StackItems(itemId)
		end,
		transferItem = function(fromSlot: number, toSlot: number)
			return inventoryController:TransferItem(fromSlot, toSlot)
		end,
		addItem = function(itemId: string, quantity: number)
			return inventoryController:AddItem(itemId, quantity)
		end,
	}
end

return useInventoryActions
