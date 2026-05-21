--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local GetEquipmentStateQuery = {}
GetEquipmentStateQuery.__index = GetEquipmentStateQuery
setmetatable(GetEquipmentStateQuery, BaseQuery)

function GetEquipmentStateQuery.new()
	local self = BaseQuery.new("Equipment", "GetEquipmentState")
	return setmetatable(self, GetEquipmentStateQuery)
end

function GetEquipmentStateQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "SyncService", "EquipmentSyncService")
end

function GetEquipmentStateQuery:Execute(): Result.Result<EquipmentTypes.TEquipmentState>
	return Ok(self.SyncService:GetStateReadOnly())
end

return GetEquipmentStateQuery
