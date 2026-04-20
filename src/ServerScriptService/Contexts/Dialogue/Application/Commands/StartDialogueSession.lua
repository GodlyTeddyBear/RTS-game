--!strict

--[=[
	@class StartDialogueSession
	Application command to initiate a dialogue session with an NPC. Validates eligibility, creates a session, and returns the initial dialogue snapshot.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local StartDialogueSession = {}
StartDialogueSession.__index = StartDialogueSession

function StartDialogueSession.new()
	return setmetatable({}, StartDialogueSession)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within StartDialogueSession
]=]
function StartDialogueSession:Init(registry: any, _name: string)
	self.StartDialoguePolicy = registry:Get("StartDialoguePolicy")
	self.DialogueTreeService = registry:Get("DialogueTreeService")
	self.DialogueSessionService = registry:Get("DialogueSessionService")
	self.DialogueFlagSyncService = registry:Get("DialogueFlagSyncService")
	self.DialogueFlagPersistenceService = registry:Get("DialogueFlagPersistenceService")
	self.NPCIdentityService = registry:Get("NPCIdentityService")
end

--[=[
	Execute the dialogue session start command. Validates eligibility, marks first-meeting flag, and builds the root node snapshot.
	@within StartDialogueSession
	@param player Player -- The player starting the conversation
	@param userId number -- The player's user ID
	@param npcId string -- The NPC identifier
	@return Result<any> -- Dialogue snapshot of the root node
]=]
function StartDialogueSession:Execute(player: Player, userId: number, npcId: string): Result.Result<any>
	local policyResult = Try(self.StartDialoguePolicy:Check(userId, npcId))
	local rootNodeId = self.DialogueTreeService:GetRootNodeId(policyResult.NPCId)
	Ensure(rootNodeId ~= nil, "DialogueTreeNotFound", Errors.DIALOGUE_TREE_NOT_FOUND)

	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId)
	Ensure(flags ~= nil, "FlagsNotLoaded", Errors.PLAYER_FLAGS_NOT_LOADED)

	local hasMetFlagName = "HasMet_" .. npcId
	if flags[hasMetFlagName] ~= true then
		self.DialogueFlagSyncService:SetFlag(userId, hasMetFlagName, true)
		flags[hasMetFlagName] = true
		Try(self.DialogueFlagPersistenceService:SaveFlags(player, flags))
	end

	self.DialogueSessionService:StartSession(userId, policyResult.NPCId, rootNodeId)
	local snapshot = Try(self.DialogueTreeService:BuildSnapshot(policyResult.NPCId, rootNodeId, flags))

	return Ok(snapshot)
end

return StartDialogueSession
