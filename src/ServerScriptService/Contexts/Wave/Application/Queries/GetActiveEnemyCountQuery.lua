--!strict

--[=[
	@class GetActiveEnemyCountQuery
	Reads the current number of active enemies in the wave session.
	@server
]=]
local GetActiveEnemyCountQuery = {}
GetActiveEnemyCountQuery.__index = GetActiveEnemyCountQuery

--[=[
	Creates a new active-enemy query.
	@within GetActiveEnemyCountQuery
	@return GetActiveEnemyCountQuery -- The new query instance.
]=]
function GetActiveEnemyCountQuery.new()
	return setmetatable({}, GetActiveEnemyCountQuery)
end

--[=[
	Wires the runtime state dependency.
	@within GetActiveEnemyCountQuery
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function GetActiveEnemyCountQuery:Init(registry: any, _name: string)
	self._state = registry:Get("WaveRuntimeStateService")
end

--[=[
	Returns the current active enemy count.
	@within GetActiveEnemyCountQuery
	@return number -- The number of living enemies in the active session.
]=]
function GetActiveEnemyCountQuery:Execute(): number
	local state = self._state:GetStateReadOnly()
	return state.activeEnemyCount
end

return GetActiveEnemyCountQuery
