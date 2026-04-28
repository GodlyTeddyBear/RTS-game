--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

local GetInventory = {}
GetInventory.__index = GetInventory
setmetatable(GetInventory, BaseQuery)

function GetInventory.new()
	local self = BaseQuery.new("Inventory", "GetInventory")
	return setmetatable(self, GetInventory)
end

function GetInventory:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "SyncService", "InventorySyncService")
end

function GetInventory:Execute(userId: number): Result.Result<any>
	Ensure(userId > 0, "InvalidUserId", Errors.INVALID_USER_ID, { userId = userId })
	return Ok(self.SyncService:EnsureInventory(userId))
end

return GetInventory
