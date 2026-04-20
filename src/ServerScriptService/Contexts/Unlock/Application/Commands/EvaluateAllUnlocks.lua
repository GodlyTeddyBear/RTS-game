--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local MentionSuccess = Result.MentionSuccess

--[=[
	@class EvaluateAllUnlocks
	Runs a full evaluation pass for a player against every auto-unlock target
	in `UnlockConfig`. Called on player join as a safety net to catch any unlocks
	earned offline or via retroactive config updates.

	Persists and syncs the atom after any new unlocks are granted.
	@server
]=]

local EvaluateAllUnlocks = {}
EvaluateAllUnlocks.__index = EvaluateAllUnlocks

function EvaluateAllUnlocks.new()
	return setmetatable({}, EvaluateAllUnlocks)
end

--[=[
	@within EvaluateAllUnlocks
	@private
]=]
function EvaluateAllUnlocks:Init(registry: any, _name: string)
	self.UnlockSyncService = registry:Get("UnlockSyncService")
	self.UnlockPersistenceService = registry:Get("UnlockPersistenceService")
	self.Registry = registry
end

--[=[
	@within EvaluateAllUnlocks
	@private
]=]
function EvaluateAllUnlocks:Start()
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
	Evaluates all auto-unlock targets for a player and applies any newly eligible unlocks.
	@within EvaluateAllUnlocks
	@param player Player -- The player to evaluate
	@param userId number -- The player's user ID
	@return Result.Result<{ string }> -- Ok with list of newly unlocked target IDs
]=]
function EvaluateAllUnlocks:Execute(player: Player, userId: number): Result.Result<{ string }>
	-- Load current unlock state; return empty if not loaded
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if not state then return Ok({}) end

	-- Fetch snapshot of all condition values
	local snapshot = self.UnlockConditionResolver:Resolve(userId)

	-- Evaluate all auto-unlocks (no filter; catches offline or retroactive unlocks)
	local newlyUnlocked = _CollectAndMarkUnlocked(
		self.UnlockConditionEvaluator,
		self.UnlockSyncService,
		userId,
		state,
		snapshot,
		nil
	)

	-- Persist and sync only if new unlocks were granted
	if #newlyUnlocked > 0 then
		self:_PersistAndSync(player, userId)
	end

	MentionSuccess("Unlock:EvaluateAllUnlocks:Execute", "Evaluated auto unlocks for player snapshot", {
		userId = userId,
		newlyUnlockedCount = #newlyUnlocked,
	})

	return Ok(newlyUnlocked)
end

--[=[
	@within EvaluateAllUnlocks
	@private
]=]
function EvaluateAllUnlocks:_PersistAndSync(player: Player, userId: number)
	-- Save updated state to profile
	local finalState = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if finalState then
		self.UnlockPersistenceService:SaveUnlockData(player, finalState)
	end

	-- Broadcast new state to client
	self.UnlockSyncService:HydratePlayer(player)
end

return EvaluateAllUnlocks
