--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)
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
		_entityFactory = "UnitEntityFactory",
	})
end

function GetActiveUnitsQuery:Execute(): Result.Result<{ number }>
	return Ok(self._entityFactory:QueryActiveEntities())
end

return GetActiveUnitsQuery
