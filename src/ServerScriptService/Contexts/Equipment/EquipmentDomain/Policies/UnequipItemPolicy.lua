--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local EquipmentSpecs = require(script.Parent.Parent.Specs.EquipmentSpecs)

type TEquippedItem = EquipmentTypes.TEquippedItem

local Ok = Result.Ok
local Try = Result.Try

local UnequipItemPolicy = {}
UnequipItemPolicy.__index = UnequipItemPolicy

function UnequipItemPolicy.new()
	return setmetatable({}, UnequipItemPolicy)
end

function UnequipItemPolicy:Init(registry: any, _name: string)
	self.SyncService = registry:Get("EquipmentSyncService")
end

function UnequipItemPolicy:Check(
	_ownerUserId: number?,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<{ OwnerKey: string, EquippedItem: TEquippedItem }>
	local ownerKey = EquipmentTypes.BuildOwnerKey(ownerKind, ownerId)
	local equippedItem = self.SyncService:GetEquippedItemReadOnly(ownerKey, slotId)

	Try(EquipmentSpecs.CanUnequip:IsSatisfiedBy({
		SlotOccupied = equippedItem ~= nil,
	}))

	return Ok({
		OwnerKey = ownerKey,
		EquippedItem = equippedItem :: TEquippedItem,
	})
end

return UnequipItemPolicy
