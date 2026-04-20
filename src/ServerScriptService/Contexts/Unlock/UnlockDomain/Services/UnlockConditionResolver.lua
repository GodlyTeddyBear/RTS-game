--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Dash = require(ReplicatedStorage.Packages.Dash)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TConditionSnapshot = UnlockTypes.TConditionSnapshot

local Try = Result.Try

--[=[
	@class UnlockConditionResolver
	Fetches all cross-context state needed to evaluate unlock conditions for a player.
	Returns a `TConditionSnapshot` consumed by specs and evaluators.

	Cross-context dependencies are resolved in `Start()` to avoid circular init ordering.
]=]

local UnlockConditionResolver = {}
UnlockConditionResolver.__index = UnlockConditionResolver

function UnlockConditionResolver.new()
	return setmetatable({}, UnlockConditionResolver)
end

--[=[
	@within UnlockConditionResolver
	@private
]=]
function UnlockConditionResolver:Init(registry: any, _name: string)
	self.Registry = registry
end

--[=[
	@within UnlockConditionResolver
	@private
]=]
function UnlockConditionResolver:Start()
	self.CommissionContext = self.Registry:Get("CommissionContext")
	self.QuestContext = self.Registry:Get("QuestContext")
	self.ShopContext = self.Registry:Get("ShopContext")
	self.WorkerContext = self.Registry:Get("WorkerContext")
	self.ProfileManager = self.Registry:Get("ProfileManager")
	self.DialogueContext = self.Registry:Get("DialogueContext")
end

--- Wraps cross-context lookups with fallback; degrades gracefully on error
local function _SafeFetch<T>(label: string, userId: number, default: T, fn: () -> T): T
	local ok, result = pcall(fn)
	if not ok then
		warn("[UnlockConditionResolver] Failed to read", label, "for", userId)
		return default
	end
	return result
end

--[=[
	Fetches a snapshot of all condition-relevant state for a player.
	Returns default values on any individual fetch failure so evaluation degrades gracefully.
	@within UnlockConditionResolver
	@param userId number -- The player's user ID
	@return TConditionSnapshot -- Current condition values for unlock evaluation
]=]
function UnlockConditionResolver:Resolve(userId: number): TConditionSnapshot
	-- Fetch commission tier; default 1 if not loaded
	local commissionTier = _SafeFetch("commission tier", userId, 1, function()
		local state = self.CommissionContext.CommissionSyncService:GetCommissionStateReadOnly(userId)
		return if state then state.CurrentTier else 1
	end)

	-- Fetch quest completion count; default 0 if no state
	local questsCompleted = _SafeFetch("quest count", userId, 0, function()
		local result = self.QuestContext:GetQuestStateForUser(userId)
		if not result.success then return 0 end
		return result.value.CompletedCount or 0
	end)

	-- Fetch player's current gold balance
	local gold = _SafeFetch("gold", userId, 0, function()
		return Try(self.ShopContext:GetPlayerGold(userId))
	end)

	-- Fetch worker count; default 0 if no workers
	local workerCount = _SafeFetch("worker count", userId, 0, function()
		local workers = Try(self.WorkerContext:GetWorkersForUser(userId))
		return Dash.count(workers or {})
	end)

	-- Fetch chapter from profile; default 1 if player offline
	local chapter = _SafeFetch("chapter", userId, 1, function()
		local player = Players:GetPlayerByUserId(userId)
		if not player then return 1 end
		local data = self.ProfileManager:GetData(player)
		return if data and data.Chapter then data.Chapter else 1
	end)

	-- Fetch dialogue flag for smelter placement (Chapter 1 milestone)
	local smelterPlaced = _SafeFetch("smelter placed", userId, false, function()
		return self.DialogueContext:GetDialogueFlag(userId, "Ch1_SmelterPlaced") == true
	end)

	-- Fetch dialogue flag for first Chapter 2 expedition victory
	local ch2FirstVictory = _SafeFetch("chapter 2 first victory", userId, false, function()
		return self.DialogueContext:GetDialogueFlag(userId, "Ch2_FirstVictory") == true
	end)

	-- Return snapshot of all unlock-relevant conditions
	return {
		CommissionTier  = commissionTier,
		QuestsCompleted = questsCompleted,
		Gold            = gold,
		WorkerCount     = workerCount,
		Chapter         = chapter,
		SmelterPlaced   = smelterPlaced,
		Ch2FirstVictory = ch2FirstVictory,
	}
end

return UnlockConditionResolver
