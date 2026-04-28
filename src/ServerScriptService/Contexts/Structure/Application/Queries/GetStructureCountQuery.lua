--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)


--[=[
	@class GetStructureCountQuery
	Returns the number of active structure entities.
	@server
]=]
local GetStructureCountQuery = {}
GetStructureCountQuery.__index = GetStructureCountQuery
setmetatable(GetStructureCountQuery, BaseQuery)

--[=[
	Creates a new structure-count query wrapper.
	@within GetStructureCountQuery
	@return GetStructureCountQuery -- The new query instance.
]=]
function GetStructureCountQuery.new()
	local self = BaseQuery.new("Structure", "GetStructureCount")
	return setmetatable(self, GetStructureCountQuery)
end

--[=[
	Resolves the entity factory used for counting active entities.
	@within GetStructureCountQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetStructureCountQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_factory = "StructureEntityFactory"
	})
end

--[=[
	Returns the current active structure count.
	@within GetStructureCountQuery
	@return number -- The active structure count.
]=]
function GetStructureCountQuery:Execute(): number
	return #self._factory:QueryActiveEntities()
end

return GetStructureCountQuery


