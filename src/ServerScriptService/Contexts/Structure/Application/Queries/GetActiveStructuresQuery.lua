--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)

local GetActiveStructuresQuery = {}
GetActiveStructuresQuery.__index = GetActiveStructuresQuery
setmetatable(GetActiveStructuresQuery, BaseQuery)

function GetActiveStructuresQuery.new()
	local self = BaseQuery.new("Structure", "GetActiveStructures")
	return setmetatable(self, GetActiveStructuresQuery)
end

function GetActiveStructuresQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_readService", "StructureEntityReadService")
end

function GetActiveStructuresQuery:Execute(): { number }
	return self._readService:QueryOperationalEntities()
end

return GetActiveStructuresQuery
