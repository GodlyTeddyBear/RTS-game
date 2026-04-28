--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)


--[=[
	@class GetActiveStructuresQuery
	Returns the active structure entities as a dense array.
	@server
]=]
local GetActiveStructuresQuery = {}
GetActiveStructuresQuery.__index = GetActiveStructuresQuery
setmetatable(GetActiveStructuresQuery, BaseQuery)

--[=[
	Creates a new active-structure query wrapper.
	@within GetActiveStructuresQuery
	@return GetActiveStructuresQuery -- The new query instance.
]=]
function GetActiveStructuresQuery.new()
	local self = BaseQuery.new("Structure", "GetActiveStructures")
	return setmetatable(self, GetActiveStructuresQuery)
end

--[=[
	Resolves the entity factory used to enumerate active entities.
	@within GetActiveStructuresQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetActiveStructuresQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_factory = "StructureEntityFactory"
	})
end

--[=[
	Returns the current active structure entity list.
	@within GetActiveStructuresQuery
	@return { number } -- The active structure entity ids.
]=]
function GetActiveStructuresQuery:Execute(): { number }
	return self._factory:QueryActiveEntities()
end

return GetActiveStructuresQuery


