--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)

--[[
	Client-Side Inventory Sync Service

	Manages CharmSync + Blink integration for inventory state on the client.
	Server filters and sends only the player's inventory via Blink.

	Architecture Pattern: CharmSync + Blink Integration
	- Blink client receives init payloads with full inventory state
	- CharmSync.client() applies payloads to atom
	- Client atom stores single TInventoryState (not a dictionary)

	Server sends: { type = "init", data = { inventories = TInventoryState } }
	Client stores: InventoriesAtom = TInventoryState (single inventory state)
]]

local InventorySyncService = {}
InventorySyncService.__index = InventorySyncService

--- Creates client-side sync service with Blink integration
function InventorySyncService.new(BlinkClient: any)
	local self = setmetatable({}, InventorySyncService)

	-- Store Blink client module for network communication
	self.BlinkClient = BlinkClient

	-- Create client atom (stores only this player's inventory)
	self.InventoriesAtom = SharedAtoms.CreateClientAtom()

	-- Create client syncer
	self.Syncer = CharmSync.client({
		atoms = {
			inventories = self.InventoriesAtom, -- lowercase to match payload
		},
		ignoreUnhydrated = true,
	})

	return self
end

--- Starts listening for sync events from server via Blink
--- This connects the Blink listener to CharmSync syncer
function InventorySyncService:Start()
	self.BlinkClient.SyncInventory.On(function(payload)
		self.Syncer:sync(payload) -- CharmSync applies init payload
	end)
end

--- Returns the client-side atom for React components
function InventorySyncService:GetInventoriesAtom()
	return self.InventoriesAtom
end

return InventorySyncService
