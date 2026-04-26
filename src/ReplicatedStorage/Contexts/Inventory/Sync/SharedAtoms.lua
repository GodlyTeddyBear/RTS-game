--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)

export type TInventorySlot = InventoryState.TInventorySlot
export type TInventoryMetadata = InventoryState.TInventoryMetadata
export type TInventoryState = InventoryState.TInventoryState

--- Server stores all players' inventories, indexed by UserId
export type TPlayerInventories = {
	[number]: TInventoryState,
}

--- Creates server-side atom for all players' inventories
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerInventories)
end

--- Creates client-side atom for current player's inventory only
local function CreateClientAtom()
	return Charm.atom({
		Slots = {},
		Metadata = {
			TotalSlots = 200,
			UsedSlots = 0,
			LastModified = 0,
		},
	} :: TInventoryState)
end

return table.freeze({
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
})
