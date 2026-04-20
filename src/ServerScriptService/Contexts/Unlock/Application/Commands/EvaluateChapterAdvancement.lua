--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChapterConfig = require(ReplicatedStorage.Contexts.Unlock.Config.ChapterConfig)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess
local Events = GameEvents.Events

--[=[
	@class EvaluateChapterAdvancement
	Checks whether a player is eligible to advance to the next chapter and, if so,
	increments their chapter and emits `ChapterAdvanced`.

	Called reactively after the same triggers as `ProcessAutoUnlocks`
	(CommissionTier, QuestsCompleted, WorkerCount changes). When the chapter advances,
	the emitted event causes `ProcessAutoUnlocks` to re-evaluate chapter-gated unlocks.
	@server
]=]

local EvaluateChapterAdvancement = {}
EvaluateChapterAdvancement.__index = EvaluateChapterAdvancement

function EvaluateChapterAdvancement.new()
	return setmetatable({}, EvaluateChapterAdvancement)
end

--[=[
	@within EvaluateChapterAdvancement
	@private
]=]
function EvaluateChapterAdvancement:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
	self.Registry = registry
end

--[=[
	@within EvaluateChapterAdvancement
	@private
]=]
function EvaluateChapterAdvancement:Start()
	self.UnlockConditionResolver = self.Registry:Get("UnlockConditionResolver")
	self.UnlockConditionEvaluator = self.Registry:Get("UnlockConditionEvaluator")
end

--[=[
	Evaluates whether the player can advance their chapter and applies the advancement if so.
	Chains upward: if the player skips multiple chapters (retroactive config), advances one at a time.
	@within EvaluateChapterAdvancement
	@param player Player -- The player to evaluate
	@param userId number -- The player's user ID
	@return Result.Result<number> -- Ok with the player's current chapter (after any advancement)
]=]
function EvaluateChapterAdvancement:Execute(player: Player, userId: number): Result.Result<number>
	local data = self.ProfileManager:GetData(player)
	if not data then return Ok(1) end

	-- Fetch all condition values
	local snapshot = self.UnlockConditionResolver:Resolve(userId)

	-- Advance one chapter at a time; re-triggered by ChapterAdvanced event if multiple chapters unlock
	repeat
		local currentChapter = data.Chapter or 1
		local nextChapter = currentChapter + 1
		local nextEntry = ChapterConfig[nextChapter]

		-- Stop if no next chapter config or conditions not met
		if not nextEntry then break end
		if not self.UnlockConditionEvaluator:MeetsAll(nextEntry.Conditions, snapshot, { IgnoreGold = true }) then break end

		-- Apply advancement and emit events
		data.Chapter = nextChapter

		GameEvents.Bus:Emit(Events.Chapter.ChapterAdvanced, userId, nextChapter)
		if nextEntry.IntroEvent then
			GameEvents.Bus:Emit(nextEntry.IntroEvent, userId)
		end

		MentionSuccess("Unlock:EvaluateChapterAdvancement:Execute", "Player advanced to new chapter", {
			userId = userId,
			newChapter = nextChapter,
		})
	until true -- single-step per call; re-triggered by the ChapterAdvanced event if needed

	return Ok(data.Chapter or 1)
end

return EvaluateChapterAdvancement
