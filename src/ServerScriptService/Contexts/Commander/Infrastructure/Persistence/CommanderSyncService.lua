--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Commander.Sync.SharedAtoms)
local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type CommanderState = CommanderTypes.CommanderState
type CooldownState = CommanderTypes.CooldownState
type SlotKey = CommanderTypes.SlotKey

--[=[
	@class CommanderSyncService
	Owns the authoritative commander atom and mutates it for server sync.
	@server
]=]
local CommanderSyncService = setmetatable({}, { __index = BaseSyncService })
CommanderSyncService.__index = CommanderSyncService

-- Builds the initial commander state so each player starts with full HP and empty cooldowns.
local function createInitialState(): CommanderState
	return {
		hp = CommanderConfig.MAX_HP,
		maxHp = CommanderConfig.MAX_HP,
		cooldowns = {} :: CooldownState,
	}
end

--[=[
	Creates a new commander sync service.
	@within CommanderSyncService
	@return CommanderSyncService -- The new sync service.
]=]
function CommanderSyncService.new()
	local self = setmetatable({}, CommanderSyncService)
	self.AtomKey = "commander"
	self.BlinkEventName = "SyncCommander"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	return self
end

--[=[
	Initializes a player's commander state in the atom.
	@within CommanderSyncService
	@param userId number -- The player user id.
]=]
function CommanderSyncService:LoadPlayer(userId: number)
	self:LoadUserData(userId, createInitialState())
end

--[=[
	Removes a player's commander state from the atom.
	@within CommanderSyncService
	@param userId number -- The player user id.
]=]
function CommanderSyncService:RemovePlayer(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Returns a deep-cloned commander state for read-only access.
	@within CommanderSyncService
	@param userId number -- The player user id.
	@return CommanderState? -- The cloned commander state, or `nil` if uninitialized.
]=]
function CommanderSyncService:GetStateReadOnly(userId: number): CommanderState?
	return self:GetReadOnly(userId)
end

-- Clones the commander entry before changing HP so Charm sees a new reference chain.
function CommanderSyncService:SetHP(userId: number, newHp: number)
	-- Clone the root atom and the commander record so the HP write is observable.
	self.Atom(function(current)
		local existing = current[userId]
		if existing == nil then
			return current
		end

		local updated = table.clone(current)
		updated[userId] = table.clone(existing)
		updated[userId].hp = math.max(0, math.min(existing.maxHp, newHp))
		return updated
	end)
end

--[=[
	Applies damage to a commander entry and returns the resulting HP.
	@within CommanderSyncService
	@param userId number -- The player user id.
	@param amount number -- The damage amount to subtract.
	@return number -- The remaining HP after damage is applied.
]=]
function CommanderSyncService:ApplyDamage(userId: number, amount: number): number
	-- Read the current state first so the mutation can be clamped against the live HP value.
	local state = self:GetStateReadOnly(userId)
	if state == nil then
		return 0
	end

	-- Clamp the incoming damage to a non-negative value before subtracting it.
	local sanitizedAmount = math.max(0, amount)
	local nextHp = math.max(0, state.hp - sanitizedAmount)
	self:SetHP(userId, nextHp)
	return nextHp
end

--[=[
	Sets a cooldown entry for an ability slot.
	@within CommanderSyncService
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The ability slot key to update.
	@param duration number -- The cooldown duration in seconds.
]=]
function CommanderSyncService:SetCooldown(userId: number, slotKey: SlotKey, duration: number)
	-- Clone each nested level touched by the cooldown write so replication sees a new path.
	self.Atom(function(current)
		local existing = current[userId]
		if existing == nil then
			return current
		end

		local updated = table.clone(current)
		updated[userId] = table.clone(existing)
		updated[userId].cooldowns = table.clone(existing.cooldowns)
		updated[userId].cooldowns[slotKey] = {
			startedAt = os.clock(),
			duration = duration,
		}
		return updated
	end)
end

--[=[
	Clears a cooldown entry for an ability slot.
	@within CommanderSyncService
	@param userId number -- The player user id.
	@param slotKey SlotKey -- The ability slot key to clear.
]=]
function CommanderSyncService:ClearCooldown(userId: number, slotKey: SlotKey)
	-- Clone each nested level touched by the cooldown removal so the patch remains visible.
	self.Atom(function(current)
		local existing = current[userId]
		if existing == nil then
			return current
		end

		local updated = table.clone(current)
		updated[userId] = table.clone(existing)
		updated[userId].cooldowns = table.clone(existing.cooldowns)
		updated[userId].cooldowns[slotKey] = nil
		return updated
	end)
end

return CommanderSyncService
