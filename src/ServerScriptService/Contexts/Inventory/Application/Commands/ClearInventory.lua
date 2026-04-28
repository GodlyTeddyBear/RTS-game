--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local ClearInventory = {}
ClearInventory.__index = ClearInventory
setmetatable(ClearInventory, BaseCommand)

function ClearInventory.new()
	local self = BaseCommand.new("Inventory", "ClearInventory")
	return setmetatable(self, ClearInventory)
end

function ClearInventory:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "SyncService", "InventorySyncService")
end

function ClearInventory:Execute(userId: number): Result.Result<any>
	Ensure(userId > 0, "InvalidArgument", Errors.INVALID_USER_ID, { userId = userId })
	self.SyncService:EnsureInventory(userId)
	self.SyncService:ClearAllSlots(userId)

	return Ok({
		Message = "Inventory cleared successfully",
	})
end

return ClearInventory
