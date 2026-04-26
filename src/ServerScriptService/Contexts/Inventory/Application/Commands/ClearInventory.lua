--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local ClearInventory = {}
ClearInventory.__index = ClearInventory

function ClearInventory.new()
	return setmetatable({}, ClearInventory)
end

function ClearInventory:Init(registry: any, _name: string)
	self.SyncService = registry:Get("InventorySyncService")
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
