--!strict

--[=[
	@class EndDialogueSession
	Application command to terminate an active dialogue session.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local EndDialogueSession = {}
EndDialogueSession.__index = EndDialogueSession

function EndDialogueSession.new()
	return setmetatable({}, EndDialogueSession)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within EndDialogueSession
]=]
function EndDialogueSession:Init(registry: any, _name: string)
	self.DialogueSessionService = registry:Get("DialogueSessionService")
end

--[=[
	Execute the dialogue session end command.
	@within EndDialogueSession
	@param userId number -- The player's user ID
	@return Result<any> -- Inactive dialogue snapshot
]=]
function EndDialogueSession:Execute(userId: number): Result.Result<any>
	self.DialogueSessionService:EndSession(userId)

	return Ok({
		Active = false,
		NPCId = nil,
		NPCName = nil,
		NodeId = nil,
		Text = nil,
		Options = {},
	})
end

return EndDialogueSession
