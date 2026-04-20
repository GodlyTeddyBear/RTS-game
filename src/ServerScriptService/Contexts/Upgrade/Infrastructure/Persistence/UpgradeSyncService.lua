--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Upgrade.Sync.SharedAtoms)
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels
type TUpgradeEnvelope = {
	upgrades: TUpgradeLevels?,
}

--[=[
	@class UpgradeSyncService
	Manages upgrade-level synchronization between server and client.

	Extends `BaseSyncService` for CharmSync + Blink wiring and defines
	only upgrade-specific mutations.

	:::caution
	All upgrade atom mutations must go through this service — never mutate
	the atom directly from outside.
	:::
	@server
]=]

local UpgradeSyncService = setmetatable({}, { __index = BaseSyncService })
UpgradeSyncService.__index = UpgradeSyncService
UpgradeSyncService.AtomKey = "upgrades"
UpgradeSyncService.BlinkEventName = "SyncUpgrades"
UpgradeSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function UpgradeSyncService.new()
	return setmetatable({}, UpgradeSyncService)
end

---
-- Read-Only Getters
---

--[=[
	Returns a deep-cloned snapshot of a player's upgrade levels, or `nil` if not loaded.
	@within UpgradeSyncService
	@param userId number
	@return TUpgradeLevels?
]=]
function UpgradeSyncService:GetUpgradeLevelsReadOnly(userId: number): TUpgradeLevels?
	local envelope = self:GetReadOnly(userId) :: TUpgradeEnvelope?
	if not envelope then
		return nil
	end
	return envelope.upgrades or {}
end

--[=[
	Returns the current level for a single upgrade (0 if not purchased or not loaded).
	@within UpgradeSyncService
	@param userId number
	@param upgradeId string
	@return number
]=]
function UpgradeSyncService:GetUpgradeLevelReadOnly(userId: number, upgradeId: string): number
	local levels = self:GetUpgradeLevelsReadOnly(userId)
	if not levels then
		return 0
	end
	return levels[upgradeId] or 0
end

--[=[
	Returns `true` if a player's upgrade state is currently loaded in memory.
	@within UpgradeSyncService
	@param userId number
	@return boolean
]=]
function UpgradeSyncService:IsPlayerLoaded(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

---
-- Centralized Mutation Methods
---

--[=[
	Bulk-loads upgrade levels for a player on join.
	@within UpgradeSyncService
	@param userId number
	@param data TUpgradeLevels -- Previously persisted upgrade levels
]=]
function UpgradeSyncService:LoadUserUpgrades(userId: number, data: TUpgradeLevels)
	self:LoadUserData(userId, {
		upgrades = data,
	})
end

--[=[
	Removes all upgrade state for a player on leave.
	@within UpgradeSyncService
	@param userId number
]=]
function UpgradeSyncService:RemoveUserUpgrades(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Sets a single upgrade to a specific level for a player.
	@within UpgradeSyncService
	@param userId number
	@param upgradeId string
	@param newLevel number
]=]
function UpgradeSyncService:SetUpgradeLevel(userId: number, upgradeId: string, newLevel: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		local userEnvelope = updated[userId] :: TUpgradeEnvelope?
		if not userEnvelope then
			return current
		end

		local newLevels = table.clone(userEnvelope.upgrades or {})
		newLevels[upgradeId] = newLevel
		updated[userId] = {
			upgrades = newLevels,
		}
		return updated
	end)
end

return UpgradeSyncService
