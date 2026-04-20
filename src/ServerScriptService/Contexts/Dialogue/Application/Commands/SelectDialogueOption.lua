--!strict

--[=[
	@class SelectDialogueOption
	Application command to advance dialogue by selecting an option, applying flag mutations, and returning the next snapshot.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local SelectDialogueOption = {}
SelectDialogueOption.__index = SelectDialogueOption

function SelectDialogueOption.new()
	return setmetatable({}, SelectDialogueOption)
end

-- Build a snapshot representing no active dialogue session.
local function _BuildInactiveSnapshot(): any
	return {
		Active = false,
		NPCId = nil,
		NPCName = nil,
		NodeId = nil,
		Text = nil,
		Options = {},
	}
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within SelectDialogueOption
]=]
function SelectDialogueOption:Init(registry: any, _name: string)
	self.DialogueTreeService = registry:Get("DialogueTreeService")
	self.DialogueSessionService = registry:Get("DialogueSessionService")
	self.DialogueFlagSyncService = registry:Get("DialogueFlagSyncService")
	self.DialogueFlagPersistenceService = registry:Get("DialogueFlagPersistenceService")
end

--[=[
	Execute the option selection command. Validates the option against required flags, applies mutations, and transitions to the next node or ends dialogue.
	@within SelectDialogueOption
	@param player Player -- The player selecting the option
	@param userId number -- The player's user ID
	@param optionId string -- The chosen option identifier
	@return Result<any> -- Updated dialogue snapshot or inactive if dialogue ends
]=]
function SelectDialogueOption:Execute(player: Player, userId: number, optionId: string): Result.Result<any>
	Ensure(type(optionId) == "string" and #optionId > 0, "InvalidOptionId", Errors.DIALOGUE_OPTION_NOT_FOUND)

	local session = self.DialogueSessionService:GetSession(userId)
	Ensure(session ~= nil, "DialogueSessionNotFound", Errors.DIALOGUE_SESSION_NOT_FOUND)

	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId)
	Ensure(flags ~= nil, "FlagsNotLoaded", Errors.PLAYER_FLAGS_NOT_LOADED)

	-- print("[SelectDialogueOption] NPCId:", session.NPCId, "NodeId:", session.NodeId, "OptionId:", optionId)
	local resolution = Try(self.DialogueTreeService:ResolveOption(session.NPCId, session.NodeId, optionId, flags))
	-- print("[SelectDialogueOption] NextNodeId:", resolution.NextNodeId, "EndDialogue:", resolution.EndDialogue)

	if next(resolution.SetFlags) ~= nil then
		self.DialogueFlagSyncService:SetFlags(userId, resolution.SetFlags)
		for flagName, flagValue in pairs(resolution.SetFlags) do
			flags[flagName] = flagValue
		end
		Try(self.DialogueFlagPersistenceService:SaveFlags(player, flags))
	end

	if resolution.EndDialogue or resolution.NextNodeId == nil then
		self.DialogueSessionService:EndSession(userId)
		return Ok(_BuildInactiveSnapshot())
	end

	self.DialogueSessionService:SetNodeId(userId, resolution.NextNodeId)
	local snapshot = Try(self.DialogueTreeService:BuildSnapshot(session.NPCId, resolution.NextNodeId, flags))
	return Ok(snapshot)
end

return SelectDialogueOption
