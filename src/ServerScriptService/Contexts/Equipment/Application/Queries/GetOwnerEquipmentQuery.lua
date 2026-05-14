--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local GetOwnerEquipmentQuery = {}
GetOwnerEquipmentQuery.__index = GetOwnerEquipmentQuery
setmetatable(GetOwnerEquipmentQuery, BaseQuery)

function GetOwnerEquipmentQuery.new()
	local self = BaseQuery.new("Equipment", "GetOwnerEquipment")
	return setmetatable(self, GetOwnerEquipmentQuery)
end

function GetOwnerEquipmentQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "SyncService", "EquipmentSyncService")
end

function GetOwnerEquipmentQuery:Execute(ownerKind: string, ownerId: string): Result.Result<EquipmentTypes.TOwnerEquipment?>
	local ownerKey = EquipmentTypes.BuildOwnerKey(ownerKind, ownerId)
	return Ok(self.SyncService:GetOwnerEquipmentReadOnly(ownerKey))
end

return GetOwnerEquipmentQuery
