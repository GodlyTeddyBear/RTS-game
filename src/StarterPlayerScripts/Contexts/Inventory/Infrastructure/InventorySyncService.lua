--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)

--[=[
	@class InventorySyncService
	Client-side sync handler for inventory state.
	Receives updates from server via Blink and maintains reactive atom.
	@client
]=]

local InventorySyncClient = setmetatable({}, { __index = BaseSyncClient })
InventorySyncClient.__index = InventorySyncClient

--[=[
	Create a new sync service bound to a Blink client.
	@within InventorySyncService
	@param BlinkClient any -- Blink remote client instance
	@return InventorySyncService
]=]
function InventorySyncClient.new(BlinkClient: any)
	local self = BaseSyncClient.new(BlinkClient, "SyncInventory", "inventories", SharedAtoms.CreateClientAtom)
	return setmetatable(self, InventorySyncClient)
end

--[=[
	Retrieve the reactive inventory state atom.
	@within InventorySyncService
	@return Charm.Atom<InventoryState> -- Inventory state atom
]=]
function InventorySyncClient:GetInventoriesAtom()
	return self:GetAtom()
end

return InventorySyncClient
