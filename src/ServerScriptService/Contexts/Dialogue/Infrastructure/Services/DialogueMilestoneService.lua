--!strict

--[=[
	@class DialogueMilestoneService
	Infrastructure service listening to game guide events and setting dialogue flags to unlock dialogue branches based on progression milestones.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Result = require(ReplicatedStorage.Utilities.Result)
local ChapterMilestones = require(script.Parent.Milestones.Chapters)

local MentionSuccess = Result.MentionSuccess

type TSubscription = {
	eventName: string,
	callback: (...any) -> (),
}

type TSubscriptionCategories = {
	[string]: { TSubscription },
}

type TChapterMilestoneModule = {
	Build: (context: any) -> TSubscriptionCategories,
}

--[[
	DialogueMilestoneService

	Listens to Guide.* game events and translates them into dialogue flags
	for the relevant player. Also sets a PendingGreet_<npcId> flag so the
	client NPCGreeterService knows to trigger an auto-bark on next approach.

	Flag naming:
		Ch1_<Milestone>        — the milestone state flag (read by tree branching)
		PendingGreet_Eldric    — cleared by the client when the player engages
]]

local DialogueMilestoneService = {}
DialogueMilestoneService.__index = DialogueMilestoneService

export type TDialogueMilestoneService = typeof(setmetatable({} :: {
	FlagSyncService: any,
	ProfileManager: any,
}, DialogueMilestoneService))

function DialogueMilestoneService.new(): TDialogueMilestoneService
	return setmetatable({} :: { FlagSyncService: any, ProfileManager: any }, DialogueMilestoneService)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within DialogueMilestoneService
]=]
function DialogueMilestoneService:Init(registry: any, _name: string)
	self.FlagSyncService = registry:Get("DialogueFlagSyncService")
	self.ProfileManager = registry:Get("ProfileManager")
end

--[=[
	Start listening to game guide events and register milestone handlers for all chapters.
	@within DialogueMilestoneService
]=]
function DialogueMilestoneService:Start()
	local events = GameEvents.Events

	local function setMilestone(userId: number, flagName: string)
		local flags = self.FlagSyncService:GetPlayerFlagsReadOnly(userId)
		if not flags or flags[flagName] then
			return
		end

		self.FlagSyncService:SetFlag(userId, flagName, true)
	end

	local function mentionChapterAdvanced(userId: number, newChapter: number)
		MentionSuccess("Dialogue:DialogueMilestoneService", "Chapter advanced", {
			userId = userId,
			newChapter = newChapter,
		})
	end

	local milestoneContext = {
		Events = events,
		setMilestone = setMilestone,
		getFlagsReadOnly = function(userId: number)
			return self.FlagSyncService:GetPlayerFlagsReadOnly(userId)
		end,
		getPlayerByUserId = function(userId: number)
			return Players:GetPlayerByUserId(userId)
		end,
		getProfileData = function(player: Player)
			return self.ProfileManager:GetData(player)
		end,
		mentionChapterAdvanced = mentionChapterAdvanced,
	}

	for _, chapterMilestoneModule: TChapterMilestoneModule in ChapterMilestones do
		local subscriptionsByCategory = chapterMilestoneModule.Build(milestoneContext)
		for _, subscriptions in subscriptionsByCategory do
			for _, subscription in subscriptions do
				GameEvents.Bus:On(subscription.eventName, subscription.callback)
			end
		end
	end
end

return DialogueMilestoneService
