--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

type CommanderState = CommanderTypes.CommanderState

--[=[
	@class GetCommanderStateQuery
	Reads authoritative commander ECS state without crossing into the domain layer.
	@server
]=]
local GetCommanderStateQuery = {}
GetCommanderStateQuery.__index = GetCommanderStateQuery
setmetatable(GetCommanderStateQuery, BaseQuery)

--[=[
	Creates a new commander-state query.
	@within GetCommanderStateQuery
	@return GetCommanderStateQuery -- The new query instance.
]=]
function GetCommanderStateQuery.new()
	local self = BaseQuery.new("Commander", "GetCommanderStateQuery")
	return setmetatable(self, GetCommanderStateQuery)
end

--[=[
	Initializes the sync dependency for commander reads.
	@within GetCommanderStateQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetCommanderStateQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "CommanderEntityFactory")
end

--[=[
	Returns the current commander state for a player.
	@within GetCommanderStateQuery
	@param userId number -- The player user id.
	@return CommanderState? -- The cloned commander state, or `nil` if unavailable.
]=]
function GetCommanderStateQuery:Execute(userId: number): CommanderState?
	return self._entityFactory:GetCommanderState(userId)
end

return GetCommanderStateQuery
