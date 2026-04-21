--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderState = CommanderTypes.CommanderState

--[=[
	@class GetCommanderStateQuery
	Reads the commander atom without crossing into the domain layer.
	@server
]=]
local GetCommanderStateQuery = {}
GetCommanderStateQuery.__index = GetCommanderStateQuery

--[=[
	Creates a new commander-state query.
	@within GetCommanderStateQuery
	@return GetCommanderStateQuery -- The new query instance.
]=]
function GetCommanderStateQuery.new()
	return setmetatable({}, GetCommanderStateQuery)
end

--[=[
	Initializes the sync dependency for commander reads.
	@within GetCommanderStateQuery
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function GetCommanderStateQuery:Init(registry: any, _name: string)
	self._syncService = registry:Get("CommanderSyncService")
end

--[=[
	Returns the current commander state for a player.
	@within GetCommanderStateQuery
	@param userId number -- The player user id.
	@return CommanderState? -- The cloned commander state, or `nil` if unavailable.
]=]
function GetCommanderStateQuery:Execute(userId: number): CommanderState?
	return self._syncService:GetStateReadOnly(userId)
end

return GetCommanderStateQuery
