--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local GetActiveUnitsQuery = {}
GetActiveUnitsQuery.__index = GetActiveUnitsQuery
setmetatable(GetActiveUnitsQuery, BaseQuery)

function GetActiveUnitsQuery.new()
	local self = BaseQuery.new("Unit", "GetActiveUnits")
	return setmetatable(self, GetActiveUnitsQuery)
end

function GetActiveUnitsQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_unitReadService = "UnitEntityReadService",
	})
end

function GetActiveUnitsQuery:Execute(): Result.Result<{ number }>
	return Ok(self._unitReadService:QueryActiveEntities())
end

return GetActiveUnitsQuery
