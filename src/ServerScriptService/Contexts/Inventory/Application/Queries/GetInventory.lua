--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local GetInventory = {}
GetInventory.__index = GetInventory

function GetInventory.new()
	return setmetatable({}, GetInventory)
end

function GetInventory:Init(registry: any, _name: string)
	self.SyncService = registry:Get("InventorySyncService")
end

function GetInventory:Execute(userId: number): Result.Result<any>
	Ensure(userId > 0, "InvalidUserId", Errors.INVALID_USER_ID, { userId = userId })
	return Ok(self.SyncService:EnsureInventory(userId))
end

return GetInventory
