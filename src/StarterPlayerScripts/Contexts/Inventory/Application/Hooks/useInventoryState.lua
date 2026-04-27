--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)

type TInventoryState = InventoryState.TInventoryState

local inventoryAtom: (() -> TInventoryState)? = nil

local function _GetInventoryAtom(): () -> TInventoryState
	if inventoryAtom == nil then
		local inventoryController = Knit.GetController("InventoryController")
		inventoryAtom = inventoryController:GetAtom()
	end

	return inventoryAtom
end

local function useInventoryState(): TInventoryState
	return ReactCharm.useAtom(_GetInventoryAtom()) :: TInventoryState
end

return useInventoryState
