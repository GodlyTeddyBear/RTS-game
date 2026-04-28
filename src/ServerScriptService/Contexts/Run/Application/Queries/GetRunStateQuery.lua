--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type RunState = RunTypes.RunState

--[=[
	@class GetRunStateQuery
	Reads the current authoritative run state.
	@server
]=]
local GetRunStateQuery = {}
GetRunStateQuery.__index = GetRunStateQuery
setmetatable(GetRunStateQuery, BaseQuery)

--[=[
	Creates a new run-state query.
	@within GetRunStateQuery
	@return GetRunStateQuery -- The new query instance.
]=]
function GetRunStateQuery.new()
	local self = BaseQuery.new("Run", "GetRunState")
	return setmetatable(self, GetRunStateQuery)
end

--[=[
	Wires the state machine dependency.
	@within GetRunStateQuery
	@param registry any -- The service registry that owns this query.
	@param name string -- The registered module name.
]=]
function GetRunStateQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine"
	})
end

--[=[
	Returns the current run state.
	@within GetRunStateQuery
	@return RunState -- The authoritative run state.
]=]
function GetRunStateQuery:Execute(): RunState
	return self._machine:GetState()
end

return GetRunStateQuery


