--!strict

--[=[
    @class PersistInventory
    Shared helper that snapshots and persists the current inventory state after a mutation.
    @server
]=]

--[[
	PersistInventory — Shared helper for snapshotting and persisting inventory state.

	Used by all Inventory commands after mutation to avoid duplicating
	the read-snapshot + save pattern in every command.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Try = Result.Try

--[=[
    Read the player's current inventory from the sync atom and persist it to ProfileStore.
    @within PersistInventory
    @param syncService any -- The InventorySyncService instance
    @param persistenceService any -- The InventoryPersistenceService instance
    @param player Player -- The player whose inventory is saved
    @param userId number -- The player's UserId
]=]
local function PersistInventory(syncService: any, persistenceService: any, player: Player, userId: number)
	-- Snapshot current atom state and persist to ProfileStore; safe no-op if inventory not found
	local currentInventory = syncService:GetInventoryReadOnly(userId)
	if currentInventory then
		Try(persistenceService:SaveInventory(player, currentInventory))
	end
end

return PersistInventory
