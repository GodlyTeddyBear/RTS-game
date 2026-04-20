--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[=[
	@function useInventoryState
	@within useInventoryState
	Subscribe to inventory state atom for reactive re-renders.
	@return InventoryState? -- Current inventory or nil if controller unavailable
]=]
local function useInventoryState()
	local inventoryController = Knit.GetController("InventoryController")
	if not inventoryController then
		warn("useInventoryState: InventoryController not available")
		return nil
	end

	-- Retrieve atom and subscribe to changes
	local inventoriesAtom = inventoryController:GetInventoriesAtom()
	return useAtom(inventoriesAtom)
end

return useInventoryState
