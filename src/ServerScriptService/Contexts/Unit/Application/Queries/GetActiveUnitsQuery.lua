--!strict

--[=[
    @class GetActiveUnitsQuery
    Returns the active unit entities tracked by the unit entity factory.

    @server
]=]

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

-- Reads the active entity bucket directly so callers receive the current authoritative unit ids.
function GetActiveUnitsQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "UnitEntityFactory",
	})
end

-- Returns the current set of active unit entities without additional filtering.
function GetActiveUnitsQuery:Execute(): Result.Result<{ number }>
	return Ok(self._entityFactory:QueryActiveEntities())
end

return GetActiveUnitsQuery
