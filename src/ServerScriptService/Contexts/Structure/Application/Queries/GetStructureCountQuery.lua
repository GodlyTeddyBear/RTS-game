--!strict

local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)

local GetStructureCountQuery = {}
GetStructureCountQuery.__index = GetStructureCountQuery
setmetatable(GetStructureCountQuery, BaseQuery)

function GetStructureCountQuery.new()
	local self = BaseQuery.new("Structure", "GetStructureCount")
	return setmetatable(self, GetStructureCountQuery)
end

function GetStructureCountQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_readService", "StructureEntityReadService")
end

function GetStructureCountQuery:Execute(): number
	return #self._readService:QueryPlacedEntities()
end

return GetStructureCountQuery
