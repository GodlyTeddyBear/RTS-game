--!strict

--[=[
	@class DialogueContext
	Manages dialogue sessions, flags, and state persistence for NPCs. Acts as the Knit service gateway for the Dialogue bounded context.
	@server
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

local Events = GameEvents.Events

local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

local FlagValidator = require(script.Parent.DialogueDomain.Services.FlagValidator)
local StartDialoguePolicy = require(script.Parent.DialogueDomain.Policies.StartDialoguePolicy)

local DialogueFlagPersistenceService = require(script.Parent.Infrastructure.Persistence.DialogueFlagPersistenceService)
local DialogueFlagSyncService = require(script.Parent.Infrastructure.Persistence.DialogueFlagSyncService)
local DialogueMilestoneService = require(script.Parent.Infrastructure.Services.DialogueMilestoneService)
local DialogueSessionService = require(script.Parent.Infrastructure.Services.DialogueSessionService)
local DialogueTreeService = require(script.Parent.Infrastructure.Services.DialogueTreeService)
local NPCIdentityService = require(script.Parent.Infrastructure.Services.NPCIdentityService)

local StartDialogueSession = require(script.Parent.Application.Commands.StartDialogueSession)
local SelectDialogueOption = require(script.Parent.Application.Commands.SelectDialogueOption)
local EndDialogueSession = require(script.Parent.Application.Commands.EndDialogueSession)
local GetDialogueSnapshot = require(script.Parent.Application.Queries.GetDialogueSnapshot)
local GetPlayerDialogueFlags = require(script.Parent.Application.Queries.GetPlayerDialogueFlags)

local DialogueContext = Knit.CreateService({
	Name = "DialogueContext",
	Client = {},
})

--[=[
	Initialize all domain, infrastructure, and application services via the Registry.
	@within DialogueContext
]=]
function DialogueContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	registry:Register("ProfileManager", ProfileManager)
	PlayerLifecycleManager:RegisterLoader("DialogueContext")

	registry:Register("FlagValidator", FlagValidator.new(), "Domain")
	registry:Register("StartDialoguePolicy", StartDialoguePolicy.new(), "Domain")

	registry:Register("DialogueFlagPersistenceService", DialogueFlagPersistenceService.new(), "Infrastructure")
	registry:Register("DialogueFlagSyncService", DialogueFlagSyncService.new(), "Infrastructure")
	registry:Register("DialogueMilestoneService", DialogueMilestoneService.new(), "Infrastructure")
	registry:Register("DialogueSessionService", DialogueSessionService.new(), "Infrastructure")
	registry:Register("DialogueTreeService", DialogueTreeService.new(), "Infrastructure")
	registry:Register("NPCIdentityService", NPCIdentityService.new(), "Infrastructure")

	registry:Register("StartDialogueSession", StartDialogueSession.new(), "Application")
	registry:Register("SelectDialogueOption", SelectDialogueOption.new(), "Application")
	registry:Register("EndDialogueSession", EndDialogueSession.new(), "Application")
	registry:Register("GetDialogueSnapshot", GetDialogueSnapshot.new(), "Application")
	registry:Register("GetPlayerDialogueFlags", GetPlayerDialogueFlags.new(), "Application")

	registry:InitAll()

	self.DialogueFlagSyncService = registry:Get("DialogueFlagSyncService")
	self.DialogueFlagPersistenceService = registry:Get("DialogueFlagPersistenceService")
	self.StartDialogueSessionService = registry:Get("StartDialogueSession")
	self.SelectDialogueOptionService = registry:Get("SelectDialogueOption")
	self.EndDialogueSessionService = registry:Get("EndDialogueSession")
	self.GetDialogueSnapshotQuery = registry:Get("GetDialogueSnapshot")
	self.GetPlayerDialogueFlagsQuery = registry:Get("GetPlayerDialogueFlags")
end

--[=[
	Wire up event listeners for player load/save lifecycle and start ordered service initialization.
	@within DialogueContext
]=]
function DialogueContext:KnitStart()
	self.Registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadDialogueFlags(player)
				PlayerLifecycleManager:NotifyLoaded(player, "DialogueContext")
			end)
			:catch(function(err)
				warn("[DialogueContext] Failed to load dialogue flags:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		Catch(function()
			self:_SaveAndCleanupDialogueFlags(player)
			return Ok(nil)
		end, "DialogueContext:ProfileSaving")
	end)

end

-- Load dialogue flags from persistent storage into the sync service when a player's profile becomes available.
function DialogueContext:_LoadDialogueFlags(player: Player)
	local userId = player.UserId
	local flags = self.DialogueFlagPersistenceService:LoadFlags(player) or {}
	self.DialogueFlagSyncService:LoadPlayerFlags(userId, flags)
end

-- Persist dialogue flags to the player's profile and remove from memory before unload.
function DialogueContext:_SaveAndCleanupDialogueFlags(player: Player)
	local userId = player.UserId
	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId)
	if flags then
		Try(self.DialogueFlagPersistenceService:SaveFlags(player, flags))
	end
	self.DialogueFlagSyncService:RemovePlayerFlags(userId)
end

-- Defensive check to load flags if not yet in memory; waits for player readiness if needed.
function DialogueContext:_EnsureFlagsLoaded(player: Player)
	local userId = player.UserId
	if self.DialogueFlagSyncService:IsPlayerLoaded(userId) then
		return
	end

	if not PlayerLifecycleManager:IsPlayerReady(player) then
		GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
	end

	local flags = self.DialogueFlagPersistenceService:LoadFlags(player) or {}
	self.DialogueFlagSyncService:LoadPlayerFlags(userId, flags)
end

--[=[
	Initiate a dialogue session with an NPC, returning a snapshot of the first dialogue node.
	@within DialogueContext
	@param player Player -- The player starting the conversation
	@param npcId string -- Identifier of the NPC to talk to
	@return Result<any> -- Dialogue snapshot containing node text and available options
]=]
function DialogueContext:StartDialogueSession(player: Player, npcId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		self:_EnsureFlagsLoaded(player)
		return self.StartDialogueSessionService:Execute(player, userId, npcId)
	end, "Dialogue:StartDialogueSession")
end

--[=[
	Advance dialogue by selecting an option, applying any flag mutations and advancing to the next node.
	@within DialogueContext
	@param player Player -- The player selecting the option
	@param optionId string -- Identifier of the chosen dialogue option
	@return Result<any> -- Updated dialogue snapshot or inactive snapshot if dialogue ends
]=]
function DialogueContext:SelectDialogueOption(player: Player, optionId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.SelectDialogueOptionService:Execute(player, userId, optionId)
	end, "Dialogue:SelectDialogueOption")
end

--[=[
	Terminate the active dialogue session.
	@within DialogueContext
	@param player Player -- The player ending the conversation
	@return Result<any> -- Inactive dialogue snapshot
]=]
function DialogueContext:EndDialogueSession(player: Player): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.EndDialogueSessionService:Execute(userId)
	end, "Dialogue:EndDialogueSession")
end

--[=[
	Query the current dialogue state (active node and available options).
	@within DialogueContext
	@param player Player -- The player querying their dialogue state
	@return Result<any> -- Current dialogue snapshot or inactive if no active session
]=]
function DialogueContext:GetDialogueSnapshot(player: Player): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.GetDialogueSnapshotQuery:Execute(userId)
	end, "Dialogue:GetDialogueSnapshot")
end

--[=[
	Fetch all dialogue flags for a player.
	@within DialogueContext
	@param player Player -- The player whose flags to retrieve
	@return Result<table> -- Key-value table of all dialogue flags
]=]
function DialogueContext:GetPlayerDialogueFlags(player: Player): Result.Result<{ [string]: any }>
	local userId = player.UserId
	return Catch(function()
		return self.GetPlayerDialogueFlagsQuery:Execute(userId)
	end, "Dialogue:GetPlayerDialogueFlags")
end

function DialogueContext:SetDialogueFlag(
	player: Player,
	userId: number,
	flagName: string,
	flagValue: any
): Result.Result<boolean>
	return Catch(function()
		self:_EnsureFlagsLoaded(player)
		self.DialogueFlagSyncService:SetFlag(userId, flagName, flagValue)

		local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId)
		if flags then
			Try(self.DialogueFlagPersistenceService:SaveFlags(player, flags))
		end

		return Ok(true)
	end, "Dialogue:SetDialogueFlag")
end

--[=[
	Request the complete dialogue state, ensuring flags are loaded first.
	@within DialogueContext
	@param player Player -- The player requesting their dialogue state
	@return Result<any> -- Current dialogue snapshot
]=]
function DialogueContext:RequestDialogueState(player: Player): Result.Result<any>
	return Catch(function()
		self:_EnsureFlagsLoaded(player)
		return self:GetDialogueSnapshot(player)
	end, "Dialogue:RequestDialogueState")
end

function DialogueContext.Client:StartDialogueSession(player: Player, npcId: string)
	return self.Server:StartDialogueSession(player, npcId)
end

function DialogueContext.Client:SelectDialogueOption(player: Player, optionId: string)
	return self.Server:SelectDialogueOption(player, optionId)
end

function DialogueContext.Client:EndDialogueSession(player: Player)
	return self.Server:EndDialogueSession(player)
end

function DialogueContext.Client:GetDialogueSnapshot(player: Player)
	return self.Server:GetDialogueSnapshot(player)
end

function DialogueContext.Client:GetPlayerDialogueFlags(player: Player)
	return self.Server:GetPlayerDialogueFlags(player)
end

function DialogueContext.Client:RequestDialogueState(player: Player)
	return self.Server:RequestDialogueState(player)
end

--[=[
	Look up a single dialogue flag by name.
	@within DialogueContext
	@param userId number -- Player user ID
	@param flagName string -- Name of the flag to retrieve
	@return any -- Flag value, or nil if not set
]=]
function DialogueContext:GetDialogueFlag(userId: number, flagName: string): any
	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId)
	if not flags then return nil end
	return flags[flagName]
end

WrapContext(DialogueContext, "DialogueContext")

return DialogueContext
