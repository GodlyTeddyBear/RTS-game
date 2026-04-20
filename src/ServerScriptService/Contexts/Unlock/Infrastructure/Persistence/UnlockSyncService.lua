--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Unlock.Sync.SharedAtoms)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState
type TUnlockEnvelope = {
	unlocks: TUnlockState?,
}

--[=[
	@class UnlockSyncService
	Manages unlock state synchronization between server and client.

	Extends `BaseSyncService` for CharmSync + Blink wiring and defines
	only unlock-specific mutations.

	:::caution
	All unlock atom mutations must go through this service — never mutate
	the atom directly from outside.
	:::
	@server
]=]

local UnlockSyncService = setmetatable({}, { __index = BaseSyncService })
UnlockSyncService.__index = UnlockSyncService
UnlockSyncService.AtomKey = "unlocks"
UnlockSyncService.BlinkEventName = "SyncUnlocks"
UnlockSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function UnlockSyncService.new()
	return setmetatable({}, UnlockSyncService)
end

---
-- Read-Only Getters
---

--[=[
	Returns a deep-cloned snapshot of a player's unlock state, or `nil` if not loaded.
	@within UnlockSyncService
	@param userId number
	@return TUnlockState?
]=]
function UnlockSyncService:GetUnlockStateReadOnly(userId: number): TUnlockState?
	local envelope = self:GetReadOnly(userId) :: TUnlockEnvelope?
	if not envelope then
		return nil
	end
	return envelope.unlocks or {}
end

--[=[
	Returns `true` if a player's unlock state is currently loaded in memory.
	@within UnlockSyncService
	@param userId number
	@return boolean
]=]
function UnlockSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

--[=[
	Returns the server-side unlock atom.
	@within UnlockSyncService
	@return any
]=]
function UnlockSyncService:GetUnlocksAtom()
	return self:GetAtom()
end

---
-- Centralized Mutation Methods
---

--[=[
	Bulk-loads unlock state for a player on join.
	@within UnlockSyncService
	@param userId number
	@param data TUnlockState -- Previously persisted unlock state
]=]
function UnlockSyncService:LoadUserUnlocks(userId: number, data: TUnlockState)
	self:LoadUserData(userId, {
		unlocks = data,
	})
end

--[=[
	Removes all unlock state for a player on leave.
	@within UnlockSyncService
	@param userId number
]=]
function UnlockSyncService:RemoveUserUnlocks(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Marks a single target as unlocked for a player.
	@within UnlockSyncService
	@param userId number
	@param targetId string -- The unlock target to mark
]=]
function UnlockSyncService:MarkUnlocked(userId: number, targetId: string)
	-- Update atom atomically: clone tree, set target true, return new tree
	self.Atom(function(current)
		local updated = table.clone(current)
		local userEnvelope = updated[userId] :: TUnlockEnvelope?
		if not userEnvelope then
			return current
		end

		-- Clone user's unlock map and mark target.
		local newState = table.clone(userEnvelope.unlocks or {})
		newState[targetId] = true
		updated[userId] = {
			unlocks = newState,
		}
		return updated
	end)
end

return UnlockSyncService
