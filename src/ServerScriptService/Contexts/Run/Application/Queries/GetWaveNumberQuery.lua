--!strict

--[=[
	@class GetWaveNumberQuery
	Reads the current authoritative wave number.
	@server
]=]
local GetWaveNumberQuery = {}
GetWaveNumberQuery.__index = GetWaveNumberQuery

--[=[
	Creates a new wave-number query.
	@within GetWaveNumberQuery
	@return GetWaveNumberQuery -- The new query instance.
]=]
function GetWaveNumberQuery.new()
	return setmetatable({}, GetWaveNumberQuery)
end

--[=[
	Wires the state machine dependency.
	@within GetWaveNumberQuery
	@param registry any -- The service registry that owns this query.
	@param name string -- The registered module name.
]=]
function GetWaveNumberQuery:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
end

--[=[
	Returns the current wave number.
	@within GetWaveNumberQuery
	@return number -- The authoritative wave number.
]=]
function GetWaveNumberQuery:Execute(): number
	return self._machine:GetWaveNumber()
end

return GetWaveNumberQuery
