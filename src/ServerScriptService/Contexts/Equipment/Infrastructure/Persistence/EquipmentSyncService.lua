--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local BaseSyncService = require(ServerStorage.Utilities.ContextUtilities.BaseSyncService)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local SharedAtoms = require(ReplicatedStorage.Contexts.Equipment.Sync.SharedAtoms)

type TEquippedItem = EquipmentTypes.TEquippedItem
type TOwnerEquipment = EquipmentTypes.TOwnerEquipment
type TEquipmentState = EquipmentTypes.TEquipmentState

local EquipmentSyncService = setmetatable({}, { __index = BaseSyncService })
EquipmentSyncService.__index = EquipmentSyncService

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, child in pairs(value) do
		clone[key] = deepClone(child)
	end
	return clone
end

function EquipmentSyncService.new()
	local self = setmetatable({}, EquipmentSyncService)
	self.AtomKey = "EquipmentState"
	self.BlinkEventName = "SyncEquipment"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	self.SyncInterval = 0.1
	return self
end

function EquipmentSyncService:Init(registry: any, _name: string)
	self.BlinkServer = registry:Get("BlinkServer")
	self.Atom = self.CreateAtom()

	self.Syncer = CharmSync.server({
		atoms = { [self.AtomKey] = self.Atom },
		interval = self.SyncInterval or 0.33,
		preserveHistory = false,
		autoSerialize = false,
	})

	self.Cleanup = self.Syncer:connect(function(player: Player, _payload: any)
		self.BlinkServer[self.BlinkEventName].Fire(player, {
			type = "init",
			data = {
				EquipmentState = self.Atom(),
			},
		})
	end)
end

function EquipmentSyncService:GetStateReadOnly(): TEquipmentState
	return deepClone(self.Atom())
end

function EquipmentSyncService:GetOwnerEquipmentReadOnly(ownerKey: string): TOwnerEquipment?
	local state = self.Atom()
	local ownerEquipment = state.Owners[ownerKey]
	return if ownerEquipment ~= nil then deepClone(ownerEquipment) else nil
end

function EquipmentSyncService:GetEquippedItemReadOnly(ownerKey: string, slotId: string): TEquippedItem?
	local ownerEquipment = self:GetOwnerEquipmentReadOnly(ownerKey)
	if ownerEquipment == nil then
		return nil
	end
	return ownerEquipment.Slots[slotId]
end

function EquipmentSyncService:SetEquipped(ownerKey: string, slotId: string, equippedItem: TEquippedItem)
	self.Atom(function(current: TEquipmentState)
		local updated: TEquipmentState = {
			Owners = table.clone(current.Owners),
		}

		local ownerEquipment = updated.Owners[ownerKey]
		local nextOwnerEquipment = {
			Slots = if ownerEquipment ~= nil then table.clone(ownerEquipment.Slots) else {},
		}
		nextOwnerEquipment.Slots[slotId] = equippedItem
		updated.Owners[ownerKey] = nextOwnerEquipment
		return updated
	end)
end

function EquipmentSyncService:ClearSlot(ownerKey: string, slotId: string)
	self.Atom(function(current: TEquipmentState)
		local ownerEquipment = current.Owners[ownerKey]
		if ownerEquipment == nil or ownerEquipment.Slots[slotId] == nil then
			return current
		end

		local updated: TEquipmentState = {
			Owners = table.clone(current.Owners),
		}
		local nextSlots = table.clone(ownerEquipment.Slots)
		nextSlots[slotId] = nil

		if next(nextSlots) == nil then
			updated.Owners[ownerKey] = nil
		else
			updated.Owners[ownerKey] = {
				Slots = nextSlots,
			}
		end

		return updated
	end)
end

function EquipmentSyncService:ClearAll()
	self.Atom(function()
		return SharedAtoms.CreateEmptyState()
	end)
end

return EquipmentSyncService
