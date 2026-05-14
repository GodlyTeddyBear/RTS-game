--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local EquipItemCommand = {}
EquipItemCommand.__index = EquipItemCommand
setmetatable(EquipItemCommand, BaseCommand)

function EquipItemCommand.new()
	local self = BaseCommand.new("Equipment", "EquipItem")
	return setmetatable(self, EquipItemCommand)
end

function EquipItemCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		EquipItemPolicy = "EquipItemPolicy",
		AttachmentService = "EquipmentAttachmentService",
		SyncService = "EquipmentSyncService",
	})
end

function EquipItemCommand:Execute(
	userId: number,
	itemId: string,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<EquipmentTypes.TEquippedItem>
	Ensure(userId > 0, "InvalidUserId", Errors.INVALID_USER_ID, { userId = userId })

	local ctx = Try(self.EquipItemPolicy:Check(userId, itemId, ownerKind, ownerId, slotId))
	local attachmentId = ctx.OwnerKey .. ":" .. slotId
	local attachmentHandle = Try(self.AttachmentService:Attach(ctx.OwnerModel, ctx.Definition, attachmentId))

	local equippedItem: EquipmentTypes.TEquippedItem = {
		ItemId = itemId,
		SlotId = slotId,
		AssetFamily = ctx.Definition.AssetFamily,
		AssetId = ctx.Definition.AssetId,
		OwnerKind = ownerKind :: EquipmentTypes.TOwnerKind,
		OwnerId = ownerId,
		EquippedAt = os.time(),
		AttachmentId = attachmentHandle.Id,
	}

	self.SyncService:SetEquipped(ctx.OwnerKey, slotId, equippedItem)
	return Ok(equippedItem)
end

return EquipItemCommand
