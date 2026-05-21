--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local UnequipItemCommand = {}
UnequipItemCommand.__index = UnequipItemCommand
setmetatable(UnequipItemCommand, BaseCommand)

function UnequipItemCommand.new()
	local self = BaseCommand.new("Equipment", "UnequipItem")
	return setmetatable(self, UnequipItemCommand)
end

function UnequipItemCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		UnequipItemPolicy = "UnequipItemPolicy",
		AttachmentService = "EquipmentAttachmentService",
		SyncService = "EquipmentSyncService",
	})
end

function UnequipItemCommand:Execute(
	userId: number,
	ownerKind: string,
	ownerId: string,
	slotId: string
): Result.Result<EquipmentTypes.TEquippedItem>
	Ensure(userId > 0, "InvalidUserId", Errors.INVALID_USER_ID, { userId = userId })

	local ctx = Try(self.UnequipItemPolicy:Check(userId, ownerKind, ownerId, slotId))
	Try(self.AttachmentService:Detach(ctx.EquippedItem.AttachmentId))
	self.SyncService:ClearSlot(ctx.OwnerKey, slotId)
	return Ok(ctx.EquippedItem)
end

return UnequipItemCommand
