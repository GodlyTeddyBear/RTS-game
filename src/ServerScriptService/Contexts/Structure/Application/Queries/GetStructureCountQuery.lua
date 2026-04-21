--!strict

--[=[
	@class GetStructureCountQuery
	Returns the number of active structure entities.
	@server
]=]
local GetStructureCountQuery = {}
GetStructureCountQuery.__index = GetStructureCountQuery

--[=[
	Creates a new structure-count query wrapper.
	@within GetStructureCountQuery
	@return GetStructureCountQuery -- The new query instance.
]=]
function GetStructureCountQuery.new()
	return setmetatable({}, GetStructureCountQuery)
end

--[=[
	Resolves the entity factory used for counting active entities.
	@within GetStructureCountQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetStructureCountQuery:Init(registry: any, _name: string)
	self._factory = registry:Get("StructureEntityFactory")
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
