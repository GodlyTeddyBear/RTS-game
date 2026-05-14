--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Contexts.Equipment.Config.EquipmentConfig)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local EquipmentSpecs = require(script.Parent.Parent.Specs.EquipmentSpecs)

type TEquipmentDefinition = EquipmentTypes.TEquipmentDefinition

local Ok = Result.Ok
local Try = Result.Try

local EquipItemPolicy = {}
EquipItemPolicy.__index = EquipItemPolicy

function EquipItemPolicy.new()
	return setmetatable({}, EquipItemPolicy)
end

function EquipItemPolicy:Init(registry: any, _name: string)
	self.SyncService = registry:Get("EquipmentSyncService")
	self.OwnerResolverService = registry:Get("EquipmentOwnerResolverService")
end

function EquipItemPolicy:Start(registry: any, _name: string)
	self.InventoryContext = registry:Get("InventoryContext")
end

function EquipItemPolicy:Check(
	userId: number,
	itemId: string,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<{ Definition: TEquipmentDefinition, OwnerModel: Model, OwnerKey: string }>
	local definition = EquipmentConfig.Definitions[itemId]
	local slot = EquipmentConfig.Slots[slotId]
	local ownerKey = EquipmentTypes.BuildOwnerKey(ownerKind, ownerId)
	local equippedItem = self.SyncService:GetEquippedItemReadOnly(ownerKey, slotId)
	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))

	local itemOwned = false
	for _, inventorySlot in pairs(inventoryState.Slots) do
		if inventorySlot.ItemId == itemId and inventorySlot.Quantity > 0 then
			itemOwned = true
			break
		end
	end

	Try(EquipmentSpecs.CanEquip:IsSatisfiedBy({
		ItemConfigured = definition ~= nil,
		SlotConfigured = slot ~= nil,
		SlotMatchesItem = definition ~= nil and definition.SlotId == slotId,
		SlotAvailable = equippedItem == nil,
		ItemOwned = itemOwned,
		OwnerResolved = true,
	}))

	local ownerModel = Try(self.OwnerResolverService:ResolveModel(ownerKind, ownerId))

	return Ok({
		Definition = definition :: TEquipmentDefinition,
		OwnerModel = ownerModel,
		OwnerKey = ownerKey,
	})
end

return EquipItemPolicy
