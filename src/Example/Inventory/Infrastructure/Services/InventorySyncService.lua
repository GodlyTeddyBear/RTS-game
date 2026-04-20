--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)

--[[
	Inventory Sync Service

	Manages inventory state synchronization between server and client using Charm atoms
	with Blink network transport and init-only payload pattern.

	Architecture Pattern: CharmSync + Blink Integration
	- CharmSync.server() provides automatic change detection and player filtering
	- Override :connect() callback to always send full state (init-only, no patches)
	- Blink handles efficient buffer serialization for network transport

	IMPORTANT: All atom mutations are centralized in this service to ensure
	proper cloning and sync behavior. Application services should NOT
	modify inventory state directly - they must use the mutation methods provided here.
]]

local InventorySyncService = {}
InventorySyncService.__index = InventorySyncService

--[[
	Deep clones a table recursively to create entirely new object references.
	This ensures CharmSync detects changes in nested structures.
]]
local function deepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end

	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = deepClone(value)
	end

	return clone
end

--- Creates server-side sync service with Blink integration
--- BlinkServer: The generated Blink server module for network transport
function InventorySyncService.new(BlinkServer: any)
	local self = setmetatable({}, InventorySyncService)

	-- Store Blink server module for network communication
	self.BlinkServer = BlinkServer

	-- Create server atom (stores all players' inventories)
	self.InventoriesAtom = SharedAtoms.CreateServerAtom()

	-- Create server syncer with Blink serialization
	self.Syncer = CharmSync.server({
		atoms = {
			inventories = self.InventoriesAtom,
		},
		interval = 0, -- Sync immediately on change
		preserveHistory = false,
		autoSerialize = false, -- Blink handles serialization
	})

	-- Override CharmSync's payload generation to always send full state (init-only)
	-- This ensures no patch merging issues with deeply nested inventory data
	self.Cleanup = self.Syncer:connect(function(player: Player, _: any)
		local userId = player.UserId
		local allInventories = self.InventoriesAtom()
		local playerInventory = allInventories[userId]

		-- Always send init with full state (or empty if no inventory exists)
		local fullStatePayload = {
			type = "init",
			data = {
				inventories = playerInventory or {},
			},
		}

		-- Send via Blink for efficient buffer serialization
		self.BlinkServer.SyncInventory.Fire(player, fullStatePayload)
	end)

	return self
end

--- Hydrates a player with current inventory state on join
function InventorySyncService:HydratePlayer(player: Player)
	self.Syncer:hydrate(player)
end

--- Returns the server-side atom for reading only
function InventorySyncService:GetInventoriesAtom()
	return self.InventoriesAtom
end

--[[
	READ-ONLY GETTERS

	These provide safe read access without allowing direct mutation.
]]

--- Gets a deep clone of a player's inventory (safe read-only access)
--- CRITICAL: Returns deep clone to prevent in-place mutations that break CharmSync
function InventorySyncService:GetInventoryReadOnly(userId: number)
	local allInventories = self.InventoriesAtom()
	local inventory = allInventories[userId]
	-- Deep clone to prevent in-place mutations that would break CharmSync change detection
	return inventory and deepClone(inventory) or nil
end

--[[
	CENTRALIZED MUTATION METHODS

	All inventory state modifications must go through these methods to ensure
	proper cloning and sync behavior. Never modify inventory state directly!
]]

--- Initialize player inventory
function InventorySyncService:CreateInventory(userId: number, maxCapacity: number)
	self.InventoriesAtom(function(current)
		local updated = table.clone(current)
		updated[userId] = table.freeze({
			Items = {},
			Capacity = 0,
			MaxCapacity = maxCapacity,
		})
		return updated
	end)
end

--- Remove player inventory
function InventorySyncService:RemoveInventory(userId: number)
	self.InventoriesAtom(function(current)
		local updated = table.clone(current)
		updated[userId] = nil
		return updated
	end)
end

--- Add item to inventory (or increase quantity if slot occupied)
function InventorySyncService:AddItem(userId: number, itemId: string, quantity: number, slotIndex: number?)
	self.InventoriesAtom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end -- No inventory for user

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local targetSlot = slotIndex or self:_FindEmptySlot(updated[userId])
		if not targetSlot then
			return updated
		end -- No space

		if updated[userId].Items[targetSlot] then
			-- Slot occupied, increase quantity
			updated[userId].Items[targetSlot] = table.clone(updated[userId].Items[targetSlot])
			updated[userId].Items[targetSlot].quantity += quantity
		else
			-- Empty slot, add new item
			updated[userId].Items[targetSlot] = table.freeze({
				itemId = itemId,
				quantity = quantity,
				slotIndex = targetSlot,
			})
			updated[userId].Capacity += 1
		end

		return updated
	end)
end

--- Remove item from inventory (or decrease quantity)
function InventorySyncService:RemoveItem(userId: number, slotIndex: number, quantity: number)
	self.InventoriesAtom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local item = updated[userId].Items[slotIndex]
		if not item then
			return updated
		end -- Slot empty

		if item.quantity <= quantity then
			-- Remove entire stack
			updated[userId].Items[slotIndex] = nil
			updated[userId].Capacity -= 1
		else
			-- Decrease quantity
			updated[userId].Items[slotIndex] = table.clone(item)
			updated[userId].Items[slotIndex].quantity = item.quantity - quantity
		end

		return updated
	end)
end

--- Update item quantity directly
function InventorySyncService:SetItemQuantity(userId: number, slotIndex: number, quantity: number)
	self.InventoriesAtom(function(current)
		local updated = table.clone(current)
		if not updated[userId] then
			return updated
		end

		updated[userId] = table.clone(updated[userId])
		updated[userId].Items = table.clone(updated[userId].Items)

		local item = updated[userId].Items[slotIndex]
		if not item then
			return updated
		end

		if quantity <= 0 then
			-- Remove item
			updated[userId].Items[slotIndex] = nil
			updated[userId].Capacity -= 1
		else
			-- Update quantity
			updated[userId].Items[slotIndex] = table.clone(item)
			updated[userId].Items[slotIndex].quantity = quantity
		end

		return updated
	end)
end

--- Helper: Find first empty slot
function InventorySyncService:_FindEmptySlot(inventory): number?
	for i = 1, inventory.MaxCapacity do
		if not inventory.Items[i] then
			return i
		end
	end
	return nil
end

--- Cleans up resources
function InventorySyncService:Destroy()
	if self.Cleanup then
		self.Cleanup()
	end
end

return InventorySyncService
