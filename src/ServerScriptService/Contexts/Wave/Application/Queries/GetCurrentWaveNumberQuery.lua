--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)


--[=[
	@class GetCurrentWaveNumberQuery
	Reads the current authoritative wave number for the session.
	@server
]=]
local GetCurrentWaveNumberQuery = {}
GetCurrentWaveNumberQuery.__index = GetCurrentWaveNumberQuery
setmetatable(GetCurrentWaveNumberQuery, BaseQuery)

--[=[
	Creates a new wave-number query.
	@within GetCurrentWaveNumberQuery
	@return GetCurrentWaveNumberQuery -- The new query instance.
]=]
function GetCurrentWaveNumberQuery.new()
	local self = BaseQuery.new("Wave", "GetCurrentWaveNumber")
	return setmetatable(self, GetCurrentWaveNumberQuery)
end

--[=[
	Wires the runtime state dependency.
	@within GetCurrentWaveNumberQuery
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function GetCurrentWaveNumberQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_state = "WaveEntityFactory"
	})
end

--[=[
	Returns the current active wave number.
	@within GetCurrentWaveNumberQuery
	@return number -- The active wave number.
]=]
function GetCurrentWaveNumberQuery:Execute(): number
	local state = self._state:GetStateReadOnly()
	return state.currentWaveNumber
end

return GetCurrentWaveNumberQuery


