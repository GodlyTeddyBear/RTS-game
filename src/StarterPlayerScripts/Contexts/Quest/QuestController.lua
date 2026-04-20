--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.QuestSyncClient)
local hudVisibilityAtom = require(script.Parent.Parent.App.Infrastructure.HudVisibilityAtom)
local navigationAtom = require(script.Parent.Parent.App.Infrastructure.NavigationAtom)

-- Infrastructure
local QuestSyncClient = require(script.Parent.Infrastructure.QuestSyncClient)

--[=[
	@class QuestController
	Client-side Knit service for quest system integration, managing state sync, UI controllers, and quest actions.
	@client
]=]
local QuestController = Knit.CreateController({
	Name = "QuestController",
})

---
-- Knit Lifecycle
---

--[=[
	Initialize the Knit controller by setting up the registry and sync service.
	@within QuestController
]=]
function QuestController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self.SyncService = QuestSyncClient.new(BlinkClient)
	registry:Register("QuestSyncClient", self.SyncService, "Infrastructure")

	registry:InitAll()
end

--[=[
	Start the Knit controller by initializing cross-context dependencies and requesting initial quest state.
	@within QuestController
]=]
function QuestController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local QuestContext = Knit.GetService("QuestContext")
	registry:Register("QuestContext", QuestContext)

	self.QuestContext = QuestContext

	registry:StartOrdered({ "Infrastructure" })

	-- Request initial state (hydration)
	task.delay(0.3, function()
		self:RequestQuestState()
	end)

	self:_ObserveExpeditionResults()
	self:_ObserveExpeditionHudLock()
end

--[=[
	Get the quest state atom for UI components to subscribe to.
	@within QuestController
	@return Charm atom containing the current quest state
]=]
function QuestController:GetQuestStateAtom()
	return self.SyncService:GetQuestStateAtom()
end

--[=[
	Request initial quest state from the server (hydration).
	@within QuestController
	@return Result<void> -- Success or error result
	@yields
]=]
function QuestController:RequestQuestState()
	return self.QuestContext:RequestQuestState()
		:catch(function(err)
			warn("[QuestController:RequestQuestState]", err.type, err.message)
		end)
end

--[=[
	Depart on a quest with the selected party of adventurers.
	@within QuestController
	@param zoneId string -- The ID of the zone to quest in
	@param partyAdventurerIds { string } -- IDs of selected adventurers
	@return Result<void> -- Success or error result
	@yields
]=]
function QuestController:DepartOnQuest(zoneId: string, partyAdventurerIds: { string })
	return self.QuestContext:DepartOnQuest(zoneId, partyAdventurerIds)
		:catch(function(err)
			warn("[QuestController:DepartOnQuest]", err.type, err.message)
		end)
end

--[=[
	Flee the current active expedition.
	@within QuestController
	@return Result<void> -- Success or error result
	@yields
]=]
function QuestController:FleeExpedition()
	return self.QuestContext:FleeExpedition()
		:catch(function(err)
			warn("[QuestController:FleeExpedition]", err.type, err.message)
		end)
end

function QuestController:AcknowledgeExpedition()
	return self.QuestContext:AcknowledgeExpedition()
		:catch(function(err)
			warn("[QuestController:AcknowledgeExpedition]", err.type, err.message)
		end)
end

function QuestController:UseExpeditionConsumable(slotIndex: number, targetNpcId: string)
	return self.QuestContext:UseExpeditionConsumable(slotIndex, targetNpcId)
		:catch(function(err)
			warn("[QuestController:UseExpeditionConsumable]", err.type, err.message)
		end)
end

function QuestController:_ObserveExpeditionResults()
	if self.ResultObserverCleanup then
		self.ResultObserverCleanup()
	end

	self.ResultObserverCleanup = Charm.subscribe(function()
		local questState = self.SyncService:GetQuestStateAtom()()
		local expedition = questState and questState.ActiveExpedition or nil
		return expedition and expedition.Status or nil
	end, function(status: string?)
		if self:_IsTerminalStatus(status) then
			self:_NavigateToExpeditionResult()
		end
	end)

	local questState = self.SyncService:GetQuestStateAtom()()
	local expedition = questState and questState.ActiveExpedition or nil
	if expedition and self:_IsTerminalStatus(expedition.Status) then
		self:_NavigateToExpeditionResult()
	end
end

function QuestController:_ObserveExpeditionHudLock()
	if self.HudLockObserverCleanup then
		self.HudLockObserverCleanup()
	end

	self.HudLockObserverCleanup = Charm.subscribe(function()
		local questState = self.SyncService:GetQuestStateAtom()()
		return questState ~= nil and questState.ActiveExpedition ~= nil
	end, function(hasActiveExpedition: boolean)
		self:_SetGameHudLocked(hasActiveExpedition)
	end)

	local questState = self.SyncService:GetQuestStateAtom()()
	self:_SetGameHudLocked(questState ~= nil and questState.ActiveExpedition ~= nil)
end

function QuestController:_SetGameHudLocked(isLocked: boolean)
	hudVisibilityAtom({
		IsGameHudEnabled = not isLocked,
		Reason = if isLocked then "Expedition" else nil,
	})
end

function QuestController:_IsTerminalStatus(status: string?): boolean
	return status == "Victory" or status == "Defeat" or status == "Fled"
end

function QuestController:_NavigateToExpeditionResult()
	local current = navigationAtom()
	if current.CurrentScreen == "QuestExpeditionResult" then
		return
	end

	local history = table.clone(current.History)
	table.insert(history, "QuestExpeditionResult")
	navigationAtom({
		CurrentScreen = "QuestExpeditionResult",
		History = history,
		Params = nil,
	})
end

return QuestController
