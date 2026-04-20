--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess

--[=[
	@class ProcessAutoUnlocks
	Evaluates auto-unlock targets for a specific trigger category
	(e.g. `"CommissionTier"`, `"QuestsCompleted"`, `"WorkerCount"`).

	Called reactively when a relevant `GameEvent` fires. Only evaluates targets
	whose conditions include the changed field — avoids unnecessary work.
	@server
]=]

local ProcessAutoUnlocks = {}
ProcessAutoUnlocks.__index = ProcessAutoUnlocks

function ProcessAutoUnlocks.new()
	return setmetatable({}, ProcessAutoUnlocks)
end

--[=[
	@within ProcessAutoUnlocks
	@private
]=]
function ProcessAutoUnlocks:Init(registry: any, _name: string)
	self.UnlockSyncService = registry:Get("UnlockSyncService")
	self.UnlockPersistenceService = registry:Get("UnlockPersistenceService")
	self.Registry = registry
end

--[=[
	@within ProcessAutoUnlocks
	@private
]=]
function ProcessAutoUnlocks:Start()
	self.UnlockConditionResolver = self.Registry:Get("UnlockConditionResolver")
	self.UnlockConditionEvaluator = self.Registry:Get("UnlockConditionEvaluator")
end

--- Iterates config, evaluates each unlock, marks newly eligible ones
local function _CollectAndMarkUnlocked(
	evaluator: any,
	syncService: any,
	userId: number,
	state: { [string]: boolean },
	snapshot: any,
	triggerField: string?
): { string }
	local newlyUnlocked: { string } = {}

	for targetId, entry in pairs(UnlockConfig) do
		-- Skip entries that are not candidates for evaluation
		if entry.StartsUnlocked then continue end
		if state[targetId] == true then continue end
		if not entry.AutoUnlock then continue end

		-- If triggerField provided, skip targets that don't include it (optimization)
		if triggerField ~= nil and not evaluator:HasConditionKey(entry.Conditions, triggerField) then continue end

		-- Evaluate eligibility and mark if satisfied
		local isEligible = evaluator:MeetsAll(entry.Conditions, snapshot, { IgnoreGold = true })
		if isEligible then
			syncService:MarkUnlocked(userId, targetId)
			table.insert(newlyUnlocked, targetId)
		end
	end

	return newlyUnlocked
end

--[=[
	Evaluates auto-unlock targets for a player, filtered to a specific trigger field.
	@within ProcessAutoUnlocks
	@param player Player -- The player to evaluate
	@param userId number -- The player's user ID
	@param triggerField string? -- Condition key that changed (e.g. `"CommissionTier"`); pass `nil` to evaluate all
	@return Result.Result<{ string }> -- Ok with list of newly unlocked target IDs
]=]
function ProcessAutoUnlocks:Execute(player: Player, userId: number, triggerField: string?): Result.Result<{ string }>
	-- Load current unlock state; return empty if not loaded
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if not state then return Ok({}) end

	-- Fetch snapshot of all condition values
	local snapshot = self.UnlockConditionResolver:Resolve(userId)

	-- Evaluate auto-unlocks filtered to triggerField if provided
	local newlyUnlocked = _CollectAndMarkUnlocked(
		self.UnlockConditionEvaluator,
		self.UnlockSyncService,
		userId,
		state,
		snapshot,
		triggerField
	)

	-- Persist and sync only if new unlocks were granted
	if #newlyUnlocked > 0 then
		self:_PersistAndSync(player, userId)
	end

	MentionSuccess("Unlock:ProcessAutoUnlocks:Execute", "Processed trigger-based auto unlock evaluation", {
		userId = userId,
		triggerField = triggerField,
		newlyUnlockedCount = #newlyUnlocked,
	})

	return Ok(newlyUnlocked)
end

--[=[
	@within ProcessAutoUnlocks
	@private
]=]
function ProcessAutoUnlocks:_PersistAndSync(player: Player, userId: number)
	-- Save updated state to profile
	local finalState = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if finalState then
		self.UnlockPersistenceService:SaveUnlockData(player, finalState)
	end

	-- Broadcast new state to client
	self.UnlockSyncService:HydratePlayer(player)
end

return ProcessAutoUnlocks
