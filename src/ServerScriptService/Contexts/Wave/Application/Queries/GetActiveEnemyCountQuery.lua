--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)


--[=[
	@class GetActiveEnemyCountQuery
	Reads the current number of active enemies in the wave session.
	@server
]=]
local GetActiveEnemyCountQuery = {}
GetActiveEnemyCountQuery.__index = GetActiveEnemyCountQuery
setmetatable(GetActiveEnemyCountQuery, BaseQuery)

--[=[
	Creates a new active-enemy query.
	@within GetActiveEnemyCountQuery
	@return GetActiveEnemyCountQuery -- The new query instance.
]=]
function GetActiveEnemyCountQuery.new()
	local self = BaseQuery.new("Wave", "GetActiveEnemyCount")
	return setmetatable(self, GetActiveEnemyCountQuery)
end

--[=[
	Wires the runtime state dependency.
	@within GetActiveEnemyCountQuery
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function GetActiveEnemyCountQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_state = "WaveEntityFactory"
	})
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


