--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type StructureRecord = PlacementTypes.StructureRecord

--[=[
	@class GetPlacedStructuresQuery
	Returns a cloned list of currently placed structures.
	@server
]=]
local GetPlacedStructuresQuery = {}
GetPlacedStructuresQuery.__index = GetPlacedStructuresQuery

--[=[
	Creates a new placement query wrapper.
	@within GetPlacedStructuresQuery
	@return GetPlacedStructuresQuery -- The new query instance.
]=]
-- The query is a thin read-only wrapper, so construction has no dependencies.
function GetPlacedStructuresQuery.new()
	return setmetatable({}, GetPlacedStructuresQuery)
end

--[=[
	Resolves the placement sync service for read-only access.
	@within GetPlacedStructuresQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
-- Resolve the sync service once so the query can stay a pure read path.
function GetPlacedStructuresQuery:Init(registry: any, _name: string)
	self._syncService = registry:Get("PlacementSyncService")
end

--[=[
	Reads the current placement list.
	@within GetPlacedStructuresQuery
	@return { StructureRecord } -- The cloned placement list.
]=]
-- Return the cloned atom snapshot so callers cannot mutate authoritative placement state.
function GetPlacedStructuresQuery:Execute(): { StructureRecord }
	return self._syncService:GetPlacementsReadOnly()
end

return GetPlacedStructuresQuery
