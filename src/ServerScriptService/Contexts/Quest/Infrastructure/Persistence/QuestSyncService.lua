--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Quest.Sync.SharedAtoms)
local QuestTypes = require(ReplicatedStorage.Contexts.Quest.Types.QuestTypes)

type TQuestState = QuestTypes.TQuestState
type TExpeditionState = QuestTypes.TExpeditionState
type TExpeditionStatus = QuestTypes.TExpeditionStatus
type TExpeditionLootItem = QuestTypes.TExpeditionLootItem

--[=[
	@class QuestSyncService
	Manages quest and expedition state synchronization. Extends BaseSyncService
	for CharmSync atom wiring and Blink hydration. All atom mutations for quest
	state are centralized here.

	:::caution
	Never mutate the atom outside this service. All writes must go through the
	methods below to preserve Charm's targeted-clone contract.
	:::
	@server
]=]

local function _DeepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end
	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = _DeepClone(value)
	end
	return clone
end

local QuestSyncService = setmetatable({}, { __index = BaseSyncService })
QuestSyncService.__index = QuestSyncService
QuestSyncService.AtomKey = "questState"
QuestSyncService.BlinkEventName = "SyncQuestState"
QuestSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function QuestSyncService.new()
	return setmetatable({}, QuestSyncService)
end

--[[
	READ-ONLY GETTERS
]]

--[=[
	Returns a deep-cloned snapshot of the player's full quest state.
	@within QuestSyncService
	@param userId number
	@return TQuestState? -- nil if not yet loaded
]=]
function QuestSyncService:GetQuestStateReadOnly(userId: number): TQuestState?
	return self:GetReadOnly(userId)
end

--[=[
	Returns a deep-cloned snapshot of the player's active expedition, or nil if
	no expedition is in progress.
	@within QuestSyncService
	@param userId number
	@return TExpeditionState?
]=]
function QuestSyncService:GetActiveExpeditionReadOnly(userId: number): TExpeditionState?
	local allStates = self.Atom()
	local state = allStates[userId]
	if not state or not state.ActiveExpedition then
		return nil
	end
	return _DeepClone(state.ActiveExpedition)
end

--[=[
	Returns true if quest state has been loaded into the atom for this user.
	@within QuestSyncService
	@param userId number
	@return boolean
]=]
function QuestSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

--[=[
	Returns the raw server-side Charm atom. Used by external systems that need
	to subscribe to state changes (e.g. unlock listeners).
	@within QuestSyncService
	@return Atom<{[number]: TQuestState}>
]=]
function QuestSyncService:GetQuestStateAtom()
	return self:GetAtom()
end

--[[
	CENTRALIZED MUTATION METHODS
]]

--[=[
	Bulk-loads quest state for a user on join. Replaces any existing entry.
	@within QuestSyncService
	@param userId number
	@param data TQuestState
]=]
function QuestSyncService:LoadUserQuestState(userId: number, data: TQuestState)
	self:LoadUserData(userId, data)
end

--[=[
	Removes all quest state for a user from the atom. Called on player leave
	after persistence has been written.
	@within QuestSyncService
	@param userId number
]=]
function QuestSyncService:RemoveUserQuestState(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Writes a new expedition as the player's active expedition.
	@within QuestSyncService
	@param userId number
	@param expedition TExpeditionState
]=]
function QuestSyncService:CreateExpedition(userId: number, expedition: TExpeditionState): ()
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = expedition
		return updated
	end)
end

--[=[
	Updates the active expedition's status and optionally records the completion timestamp.
	@within QuestSyncService
	@param userId number
	@param status TExpeditionStatus
	@param completedAt number? -- Unix timestamp; omit to leave unset
]=]
function QuestSyncService:SetExpeditionStatus(userId: number, status: TExpeditionStatus, completedAt: number?)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = table.clone(updated[userId].ActiveExpedition) -- Level 3
		updated[userId].ActiveExpedition.Status = status
		if completedAt then
			updated[userId].ActiveExpedition.CompletedAt = completedAt
		end
		return updated
	end)
end

--[=[
	Records the loot drops on the active expedition.
	@within QuestSyncService
	@param userId number
	@param loot {[string]: number} -- ItemId → quantity map
]=]
function QuestSyncService:SetExpeditionLoot(userId: number, loot: { [string]: number })
	local lootItems = self:_BuildLootItems(loot)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = table.clone(updated[userId].ActiveExpedition) -- Level 3
		updated[userId].ActiveExpedition.Loot = lootItems
		return updated
	end)
end

--[=[
	Records the gold awarded on the active expedition.
	@within QuestSyncService
	@param userId number
	@param goldEarned number
]=]
function QuestSyncService:SetExpeditionGoldEarned(userId: number, goldEarned: number)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = table.clone(updated[userId].ActiveExpedition) -- Level 3
		updated[userId].ActiveExpedition.GoldEarned = goldEarned
		return updated
	end)
end

--[=[
	Records adventurers lost before permadeath removes them from guild state.
	@within QuestSyncService
	@param userId number
	@param ids {string}
]=]
function QuestSyncService:SetDeadAdventurers(userId: number, ids: { string })
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = table.clone(updated[userId].ActiveExpedition) -- Level 3
		updated[userId].ActiveExpedition.DeadAdventurerIds = table.clone(ids)
		return updated
	end)
end

--[=[
	Sets the active expedition to nil. Used during rollback when dungeon generation fails.
	@within QuestSyncService
	@param userId number
]=]
function QuestSyncService:ClearActiveExpedition(userId: number)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].ActiveExpedition = nil
		return updated
	end)
end

--[=[
	Increments the player's completed expedition counter by one.
	@within QuestSyncService
	@param userId number
]=]
function QuestSyncService:IncrementCompletedCount(userId: number)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].CompletedCount = (updated[userId].CompletedCount or 0) + 1
		return updated
	end)
end

function QuestSyncService:_BuildLootItems(loot: { [string]: number }): { TExpeditionLootItem }
	local lootItems: { TExpeditionLootItem } = {}
	for itemId, quantity in pairs(loot) do
		table.insert(lootItems, {
			ItemId = itemId,
			Quantity = quantity,
		})
	end
	table.sort(lootItems, function(left, right)
		return left.ItemId < right.ItemId
	end)
	return lootItems
end

return QuestSyncService
