--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[=[
	@function useShopInventory
	@within ShopController
	Subscribe to the player's inventory state reactively. Acts as a Shop-owned proxy so Shop does not import directly from the Inventory context.
	@return table? -- Inventory state or nil if InventoryController is unavailable
]=]
local function useShopInventory()
	local inventoryController = Knit.GetController("InventoryController")
	if not inventoryController then
		warn("useShopInventory: InventoryController not available")
		return nil
	end
	local inventoriesAtom = inventoryController:GetInventoriesAtom()
	return useAtom(inventoriesAtom)
end

return useShopInventory
