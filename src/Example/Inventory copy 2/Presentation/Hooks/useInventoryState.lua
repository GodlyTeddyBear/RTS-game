--!strict

--[[
	useInventoryState - React hook for accessing inventory state atom

	Replaces the InventoryState wrapper with a proper React hook pattern.
	Provides direct access to the inventory controller's atom and subscribes to changes.

	Usage:
		local inventories = useInventoryState()
		-- inventories is the current inventory state from the atom
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[[
	Hook that subscribes to inventory state atom from InventoryController.

	@return Current inventory state from the atom (or nil if controller not available)
]]
local function useInventoryState()
	local inventoryController = Knit.GetController("InventoryController")
	if not inventoryController then
		warn("useInventoryState: InventoryController not available")
		return nil
	end
	local inventoriesAtom = inventoryController:GetInventoriesAtom()
	return useAtom(inventoriesAtom)
end

return useInventoryState
