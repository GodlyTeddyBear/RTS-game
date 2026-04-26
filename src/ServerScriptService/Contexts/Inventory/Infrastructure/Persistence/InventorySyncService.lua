--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)

type TInventorySlot = InventoryState.TInventorySlot
type TInventoryState = InventoryState.TInventoryState

local DEFAULT_TOTAL_SLOTS = 200

local InventorySyncService = setmetatable({}, { __index = BaseSyncService })
InventorySyncService.__index = InventorySyncService
InventorySyncService.AtomKey = "inventories"
InventorySyncService.BlinkEventName = "SyncInventory"
InventorySyncService.CreateAtom = SharedAtoms.CreateServerAtom

function InventorySyncService.new()
	return setmetatable({}, InventorySyncService)
end

function InventorySyncService:GetInventoryReadOnly(userId: number): TInventoryState?
	return self:GetReadOnly(userId)
end

function InventorySyncService:GetInventoriesAtom()
	return self:GetAtom()
end

function InventorySyncService:CreateInventory(userId: number, maxCapacity: number?)
	self:LoadUserData(userId, {
		Slots = {},
		Metadata = {
			TotalSlots = maxCapacity or DEFAULT_TOTAL_SLOTS,
			UsedSlots = 0,
			LastModified = 0,
		},
	})
end

function InventorySyncService:ResetInventory(userId: number)
	self:CreateInventory(userId, DEFAULT_TOTAL_SLOTS)
end

function InventorySyncService:EnsureInventory(userId: number): TInventoryState
	local existing = self:GetInventoryReadOnly(userId)
	if existing ~= nil then
		return existing
	end

	self:CreateInventory(userId, DEFAULT_TOTAL_SLOTS)
	return self:GetInventoryReadOnly(userId) :: TInventoryState
end

function InventorySyncService:RemoveInventory(userId: number)
	self:RemoveUserData(userId)
end

function InventorySyncService:SetSlot(userId: number, slotIndex: number, slotData: TInventorySlot?)
	self.Atom(function(current)
		local updated = table.clone(current)
		local inventory = updated[userId]
		if inventory == nil then
			return updated
		end

		local nextInventory = table.clone(inventory)
		nextInventory.Slots = table.clone(inventory.Slots)
		nextInventory.Slots[slotIndex] = slotData
		updated[userId] = nextInventory

		return updated
	end)
end

function InventorySyncService:UpdateSlotQuantity(userId: number, slotIndex: number, newQuantity: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		local inventory = updated[userId]
		if inventory == nil then
			return updated
		end

		local slot = inventory.Slots[slotIndex]
		if slot == nil then
			return updated
		end

		local nextInventory = table.clone(inventory)
		nextInventory.Slots = table.clone(inventory.Slots)
		if newQuantity <= 0 then
			nextInventory.Slots[slotIndex] = nil
		else
			local nextSlot = table.clone(slot)
			nextSlot.Quantity = newQuantity
			nextInventory.Slots[slotIndex] = nextSlot
		end
		updated[userId] = nextInventory

		return updated
	end)
end

function InventorySyncService:ClearAllSlots(userId: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		local inventory = updated[userId]
		if inventory == nil then
			return updated
		end

		local nextInventory = table.clone(inventory)
		nextInventory.Slots = {}
		nextInventory.Metadata = table.clone(inventory.Metadata)
		nextInventory.Metadata.UsedSlots = 0
		nextInventory.Metadata.LastModified = os.time()
		updated[userId] = nextInventory

		return updated
	end)
end

function InventorySyncService:UpdateMetadata(userId: number, metadata: { [string]: any })
	self.Atom(function(current)
		local updated = table.clone(current)
		local inventory = updated[userId]
		if inventory == nil then
			return updated
		end

		local nextInventory = table.clone(inventory)
		nextInventory.Metadata = table.clone(inventory.Metadata)
		for key, value in pairs(metadata) do
			nextInventory.Metadata[key] = value
		end
		updated[userId] = nextInventory

		return updated
	end)
end

return InventorySyncService
