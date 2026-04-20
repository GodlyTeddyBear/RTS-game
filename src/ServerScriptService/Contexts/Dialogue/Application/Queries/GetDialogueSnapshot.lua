--!strict

--[=[
	@class GetDialogueSnapshot
	Application query to fetch the current dialogue state (active node and available options).
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local GetDialogueSnapshot = {}
GetDialogueSnapshot.__index = GetDialogueSnapshot

function GetDialogueSnapshot.new()
	return setmetatable({}, GetDialogueSnapshot)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within GetDialogueSnapshot
]=]
function GetDialogueSnapshot:Init(registry: any, _name: string)
	self.DialogueTreeService = registry:Get("DialogueTreeService")
	self.DialogueSessionService = registry:Get("DialogueSessionService")
	self.DialogueFlagSyncService = registry:Get("DialogueFlagSyncService")
end

--[=[
	Execute the snapshot query. Returns the active session snapshot or an inactive snapshot if no session exists.
	@within GetDialogueSnapshot
	@param userId number -- The player's user ID
	@return Result<any> -- Current dialogue snapshot
]=]
function GetDialogueSnapshot:Execute(userId: number): Result.Result<any>
	local session = self.DialogueSessionService:GetSession(userId)
	if not session then
		return Ok({
			Active = false,
			NPCId = nil,
			NPCName = nil,
			NodeId = nil,
			Text = nil,
			Options = {},
		})
	end

	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId) or {}
	return self.DialogueTreeService:BuildSnapshot(session.NPCId, session.NodeId, flags)
end

return GetDialogueSnapshot
