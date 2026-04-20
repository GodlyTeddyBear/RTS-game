--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Shop.Sync.SharedAtoms)
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err

--[=[
	@class GoldSyncService
	Infrastructure service managing gold state synchronization via atoms and profile persistence.
	@server
]=]
local GoldSyncService = setmetatable({}, { __index = BaseSyncService })
GoldSyncService.__index = GoldSyncService
GoldSyncService.AtomKey = "gold"
GoldSyncService.BlinkEventName = "SyncGold"
GoldSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function GoldSyncService.new()
	return setmetatable({}, GoldSyncService)
end

--[=[
	Initialize GoldSyncService with registry and profile manager.
	@within GoldSyncService
	@param registry any -- Service registry
	@param name string -- Service name
]=]
function GoldSyncService:Init(registry: any, name: string)
	BaseSyncService.Init(self, registry, name)
	self.ProfileManager = registry:Get("ProfileManager")
end

--[=[
	Get a player's current gold (read-only).
	@within GoldSyncService
	@param userId number -- The player's user ID
	@return number -- Current gold amount, or 0 if not loaded
]=]
function GoldSyncService:GetGoldReadOnly(userId: number): number
	local allGold = self.Atom()
	return allGold[userId] or 0
end

--[=[
	Check if a player's gold is loaded in the atom.
	@within GoldSyncService
	@param userId number -- The player's user ID
	@return boolean -- True if loaded, false otherwise
]=]
function GoldSyncService:IsPlayerLoaded(userId: number): boolean
	local allGold = self.Atom()
	return allGold[userId] ~= nil
end

--[=[
	Get the gold atom directly.
	@within GoldSyncService
	@return any -- The gold atom
]=]
function GoldSyncService:GetGoldAtom()
	return self:GetAtom()
end

-- Load player gold into the atom on join.
function GoldSyncService:LoadPlayerGold(userId: number, amount: number)
	self:LoadUserData(userId, amount)
end

-- Remove player gold from the atom on player leave.
function GoldSyncService:RemovePlayerGold(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Add gold to a player's balance (updates atom and profile).
	@within GoldSyncService
	@param player Player -- The player
	@param userId number -- The player's user ID
	@param amount number -- The amount to add (must be > 0)
	@return Result<number> -- Success with new gold amount, or error if amount invalid
	@error "InvalidAmount" -- Thrown if amount <= 0
]=]
function GoldSyncService:AddGold(player: Player, userId: number, amount: number): Result.Result<number>
	if amount <= 0 then
		return Err("InvalidAmount", "Amount must be greater than 0", { amount = amount })
	end

	-- Update atom with cloned state to ensure Charm reactivity
	local newGold = 0
	self.Atom(function(current)
		local updated = table.clone(current)
		local currentGold = updated[userId] or 0
		newGold = currentGold + amount
		updated[userId] = newGold
		return updated
	end)

	-- Persist to profile
	local data = self.ProfileManager:GetData(player)
	if data then
		data.Gold = newGold
	end
	return Ok(newGold)
end

--[=[
	Remove gold from a player's balance (updates atom and profile).
	@within GoldSyncService
	@param player Player -- The player
	@param userId number -- The player's user ID
	@param amount number -- The amount to remove (must be > 0)
	@return Result<number> -- Success with new gold amount, or error if insufficient or invalid amount
	@error "InvalidAmount" -- Thrown if amount <= 0
	@error "InsufficientGold" -- Thrown if player has less gold than requested
]=]
function GoldSyncService:RemoveGold(player: Player, userId: number, amount: number): Result.Result<number>
	if amount <= 0 then
		return Err("InvalidAmount", "Amount must be greater than 0", { amount = amount })
	end

	-- Validate precondition before mutation
	local currentGold = self:GetGoldReadOnly(userId)
	if currentGold < amount then
		return Err("InsufficientGold", "Not enough gold", { has = currentGold, needs = amount })
	end

	-- Update atom with cloned state to ensure Charm reactivity
	local newGold = 0
	self.Atom(function(current)
		local updated = table.clone(current)
		local gold = updated[userId] or 0
		newGold = gold - amount
		updated[userId] = newGold
		return updated
	end)

	-- Persist to profile
	local data = self.ProfileManager:GetData(player)
	if data then
		data.Gold = newGold
	end
	return Ok(newGold)
end

return GoldSyncService
