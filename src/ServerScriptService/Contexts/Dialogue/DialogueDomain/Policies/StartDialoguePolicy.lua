--!strict

--[=[
	@class StartDialoguePolicy
	Domain policy to validate preconditions for starting a dialogue session with an NPC.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ensure = Result.Ensure
local Ok = Result.Ok

local StartDialoguePolicy = {}
StartDialoguePolicy.__index = StartDialoguePolicy

export type TStartDialoguePolicy = typeof(setmetatable({}, StartDialoguePolicy))

function StartDialoguePolicy.new(): TStartDialoguePolicy
	return setmetatable({}, StartDialoguePolicy)
end

--[=[
	Initialize policy with injected dependencies from the registry.
	@within StartDialoguePolicy
]=]
function StartDialoguePolicy:Init(registry: any, _name: string)
	self.NPCIdentityService = registry:Get("NPCIdentityService")
end

--[=[
	Check eligibility to start dialogue. Validates user ID and NPC ID existence.
	@within StartDialoguePolicy
	@param userId number -- The player's user ID
	@param npcId string -- The NPC identifier
	@return Result<table> -- Success with normalized NPC ID if eligible
]=]
function StartDialoguePolicy:Check(userId: number, npcId: string): Result.Result<{ NPCId: string }>
	Ensure(userId > 0, "InvalidUserId", Errors.INVALID_USER_ID)
	Ensure(type(npcId) == "string" and #npcId > 0, "InvalidNPCId", Errors.INVALID_NPC_ID)
	Ensure(self.NPCIdentityService:IsDialogueNPC(npcId), "InvalidNPCId", Errors.INVALID_NPC_ID)

	return Ok({
		NPCId = npcId,
	})
end

return StartDialoguePolicy
