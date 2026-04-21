--!strict

--[=[
	@class GetActiveStructuresQuery
	Returns the active structure entities as a dense array.
	@server
]=]
local GetActiveStructuresQuery = {}
GetActiveStructuresQuery.__index = GetActiveStructuresQuery

--[=[
	Creates a new active-structure query wrapper.
	@within GetActiveStructuresQuery
	@return GetActiveStructuresQuery -- The new query instance.
]=]
function GetActiveStructuresQuery.new()
	return setmetatable({}, GetActiveStructuresQuery)
end

--[=[
	Resolves the entity factory used to enumerate active entities.
	@within GetActiveStructuresQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetActiveStructuresQuery:Init(registry: any, _name: string)
	self._factory = registry:Get("StructureEntityFactory")
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
