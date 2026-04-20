--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Charm = require(ReplicatedStorage.Packages.Charm)
local BlinkClient = require(ReplicatedStorage.Network.Generated.NPCFlagSyncClient)

-- Infrastructure
local NPCSyncService = require(script.Parent.Infrastructure.NPCSyncService)
local NPCDiscoveryService = require(script.Parent.Infrastructure.NPCDiscoveryService)
local DialogueManager = require(script.Parent.Infrastructure.DialogueManager)

-- Registry
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)

--[[
	NPC Controller

	Client-side Knit controller for the NPC system.
	Manages:
	- Flag sync (receives player flags from server via CharmSync+Blink)
	- NPC discovery (finds NPC models via CollectionService tags)
	- Dialogue orchestration (creates DialogueManager per NPC)
	- Flag reading/setting for dialogue conditions

	Dialogue trees are loaded from ModuleScripts via DialogueRegistry.
	Conditions read from the synced flags atom (instant, no remote call).
	Flag mutations fire remotes to the server for validation and persistence.
]]

local NPCController = Knit.CreateController({
	Name = "NPCController",
})

---
-- Knit Lifecycle
---

function NPCController:KnitInit()
	-- Create sync service with BlinkClient
	self.SyncService = NPCSyncService.new(BlinkClient)

	-- Create NPC discovery service
	self.DiscoveryService = NPCDiscoveryService.new()

	-- Create dialogue registry from dialogue trees folder
	local dialoguesFolder = script.Parent:FindFirstChild("DialogueTrees")
	if dialoguesFolder then
		self.DialogueRegistry = AssetFetcher.CreateDialogueRegistry(dialoguesFolder)
	else
		warn("[NPCController] DialogueTrees folder not found under NPCController script")
	end

	-- Active dialogue managers by model reference
	self._dialogueManagers = {} :: { [Model]: any }

	print("NPCController initialized")
end

function NPCController:KnitStart()
	-- Get server NPC context
	self.NPCContext = Knit.GetService("NPCContext")

	-- Start listening to Blink flag sync
	self.SyncService:Start()

	-- Request initial flag state (hydration)
	task.delay(0.3, function()
		self:RequestFlagState()
	end)

	-- Start NPC discovery (processes existing + listens for new NPCs)
	self.DiscoveryService:Start(
		function(model: Model, npcId: string)
			self:_OnNPCAdded(model, npcId)
		end,
		function(model: Model)
			self:_OnNPCRemoved(model)
		end
	)

	print("NPCController started")
end

---
-- NPC Lifecycle Callbacks
---

function NPCController:_OnNPCAdded(model: Model, npcId: string)
	-- Skip if already managed
	if self._dialogueManagers[model] then
		return
	end

	-- Skip if no dialogue registry
	if not self.DialogueRegistry then
		warn("[NPCController] Cannot create dialogue for", npcId, "- no DialogueRegistry")
		return
	end

	-- Skip if no dialogue tree exists for this NPC
	if not self.DialogueRegistry:Exists(npcId) then
		warn("[NPCController] No dialogue tree found for NPC:", npcId)
		return
	end

	-- Create flag reader/setter closures
	local flagReader = function(flagName: string): any
		return self:GetFlag(flagName)
	end

	local flagSetter = function(flagName: string, flagValue: any)
		self:SetFlag(flagName, flagValue)
	end

	-- Create dialogue manager
	local manager = DialogueManager.new(
		model,
		npcId,
		self.DialogueRegistry,
		flagReader,
		flagSetter,
		self.NPCContext
	)

	-- Register tree selectors for this NPC (tree swapping rules)
	-- Add more selectors here for different NPCs as needed
	if npcId == "Eldric" then
		manager:AddTreeSelector("EldricQuestComplete", true, "QuestComplete")
	end

	self._dialogueManagers[model] = manager
end

function NPCController:_OnNPCRemoved(model: Model)
	local manager = self._dialogueManagers[model]
	if manager then
		manager:Destroy()
		self._dialogueManagers[model] = nil
	end
end

---
-- Public API Methods
---

--- Get the flags atom for React UI components
function NPCController:GetFlagsAtom()
	return self.SyncService:GetFlagsAtom()
end

--- Read a flag value from the client-side synced atom (instant, no remote call)
function NPCController:GetFlag(flagName: string): any
	local flags = Charm.peek(self.SyncService:GetFlagsAtom())
	return flags[flagName]
end

--- Set a flag on the server (fires remote, returns success tuple)
function NPCController:SetFlag(flagName: string, flagValue: any): (boolean, string?)
	local _, success, data = self.NPCContext:SetFlag(flagName, flagValue):await()
	return success, data
end

--- Get all flags from server
function NPCController:GetFlags(): (boolean, any)
	local _, success, data = self.NPCContext:GetFlags():await()
	return success, data
end

--- Request flag state hydration from server
function NPCController:RequestFlagState()
	local _, result = self.NPCContext:RequestFlagState():await()
	return result
end

--- Called by DialogueModal React component when player selects an option
function NPCController:SelectDialogueOption(optionIndex: number)
	for _, manager in pairs(self._dialogueManagers) do
		if manager:IsInDialogue() then
			manager:SelectOption(optionIndex)
			return
		end
	end
end

return NPCController
