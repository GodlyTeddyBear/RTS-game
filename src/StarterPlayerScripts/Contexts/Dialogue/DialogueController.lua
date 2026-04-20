--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local DialogueSyncClient = require(script.Parent.Infrastructure.DialogueSyncClient)
local NPCInteractionService = require(script.Parent.Infrastructure.NPCInteractionService)

local Events = GameEvents.Events

--[=[
	@class DialogueController
	Knit controller that manages dialogue state synchronization and NPC interactions on the client.
	@client
]=]
local DialogueController = Knit.CreateController({
	Name = "DialogueController",
})

--[=[
	Initialize the controller by creating and registering infrastructure services.
	@within DialogueController
]=]
function DialogueController:KnitInit()
	self.Registry = Registry.new("Client")
	self.Registry:Register("DialogueSyncClient", DialogueSyncClient.new(), "Infrastructure")
	self.Registry:Register("NPCInteractionService", NPCInteractionService.new(), "Infrastructure")
	self.Registry:InitAll()

	self.SyncClient = self.Registry:Get("DialogueSyncClient")
	self.InteractionService = self.Registry:Get("NPCInteractionService")
end

--[=[
	Start the controller by wiring up NPC interactions and requesting initial dialogue state.
	@within DialogueController
]=]
function DialogueController:KnitStart()
	self.DialogueContext = Knit.GetService("DialogueContext")

	self.InteractionService:Start(function(npcId: string)
		self:StartDialogueSession(npcId)
	end)

	-- Delay to allow service initialization
	task.delay(0.3, function()
		self:RequestDialogueState()
	end)
end

--[=[
	Get the dialogue state atom for subscribing to state changes.
	@within DialogueController
	@return any -- The dialogue state atom
]=]
function DialogueController:GetDialogueStateAtom()
	return self.SyncClient:GetDialogueStateAtom()
end

--[=[
	Start a dialogue session with an NPC and sync the state.
	@within DialogueController
	@param npcId string -- The unique identifier of the NPC to talk to
	@return Result<any> -- The dialogue snapshot on success
]=]
function DialogueController:StartDialogueSession(npcId: string)
	return self.DialogueContext:StartDialogueSession(npcId)
		:andThen(function(snapshot)
			self.SyncClient:SetSnapshot(snapshot)
			return snapshot
		end)
		:catch(function(err)
			warn("[DialogueController:StartDialogueSession]", err.type, err.message)
		end)
end

--[=[
	Select a dialogue option and advance the conversation.
	@within DialogueController
	@param optionId string -- The unique identifier of the selected option
	@return Result<any> -- The updated dialogue snapshot on success
]=]
function DialogueController:SelectDialogueOption(optionId: string)
	return self.DialogueContext:SelectDialogueOption(optionId)
		:andThen(function(snapshot)
			self.SyncClient:SetSnapshot(snapshot)
			GameEvents.Bus:Emit(Events.Dialogue.OptionSelected, optionId)
			return snapshot
		end)
		:catch(function(err)
			warn("[DialogueController:SelectDialogueOption]", err.type, err.message)
		end)
end

--[=[
	End the current dialogue session.
	@within DialogueController
	@return Result<any> -- The final dialogue snapshot on success
]=]
function DialogueController:EndDialogueSession()
	return self.DialogueContext:EndDialogueSession()
		:andThen(function(snapshot)
			self.SyncClient:SetSnapshot(snapshot)
			return snapshot
		end)
		:catch(function(err)
			warn("[DialogueController:EndDialogueSession]", err.type, err.message)
		end)
end

--[=[
	Request the current dialogue state from the server.
	@within DialogueController
	@return Result<any> -- The dialogue snapshot on success
]=]
function DialogueController:RequestDialogueState()
	return self.DialogueContext:RequestDialogueState()
		:andThen(function(snapshot)
			self.SyncClient:SetSnapshot(snapshot)
			return snapshot
		end)
		:catch(function(err)
			warn("[DialogueController:RequestDialogueState]", err.type, err.message)
		end)
end

return DialogueController
