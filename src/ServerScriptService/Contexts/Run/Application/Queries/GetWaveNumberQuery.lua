--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)


--[=[
	@class GetWaveNumberQuery
	Reads the current authoritative wave number.
	@server
]=]
local GetWaveNumberQuery = {}
GetWaveNumberQuery.__index = GetWaveNumberQuery
setmetatable(GetWaveNumberQuery, BaseQuery)

--[=[
	Creates a new wave-number query.
	@within GetWaveNumberQuery
	@return GetWaveNumberQuery -- The new query instance.
]=]
function GetWaveNumberQuery.new()
	local self = BaseQuery.new("Run", "GetWaveNumber")
	return setmetatable(self, GetWaveNumberQuery)
end

--[=[
	Wires the state machine dependency.
	@within GetWaveNumberQuery
	@param registry any -- The service registry that owns this query.
	@param name string -- The registered module name.
]=]
function GetWaveNumberQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine"
	})
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


