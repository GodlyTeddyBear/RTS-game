--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

local ClearEquipmentCommand = {}
ClearEquipmentCommand.__index = ClearEquipmentCommand
setmetatable(ClearEquipmentCommand, BaseCommand)

function ClearEquipmentCommand.new()
	local self = BaseCommand.new("Equipment", "ClearEquipment")
	return setmetatable(self, ClearEquipmentCommand)
end

function ClearEquipmentCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		AttachmentService = "EquipmentAttachmentService",
		SyncService = "EquipmentSyncService",
	})
end

function ClearEquipmentCommand:Execute(): Result.Result<boolean>
	Try(self.AttachmentService:ClearAll())
	self.SyncService:ClearAll()
	return Ok(true)
end

return ClearEquipmentCommand
