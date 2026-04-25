--!strict

--[[
	Module: ResourceSyncService
	Purpose: Owns the per-player economy wallet atom and publishes sync-safe mutations.
	Used In System: Invoked by Economy application commands and queries on the server.
	Boundaries: Owns atom cloning and transport-facing sync only; does not own validation or persistence.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Economy.Sync.SharedAtoms)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

type ResourceWallet = EconomyTypes.ResourceWallet
type ProfileRunStats = EconomyTypes.ProfileRunStats
type ResourceCostMap = EconomyTypes.ResourceCostMap

-- [Private Helpers]

local function cloneRunStats(runStats: ProfileRunStats?): ProfileRunStats?
	if runStats == nil then
		return nil
	end

	return {
		TotalRuns = runStats.TotalRuns,
		BestWave = runStats.BestWave,
		TotalWavesCleared = runStats.TotalWavesCleared,
	}
end

--[=[
	@class ResourceSyncService
	Owns the per-player economy wallet atom and syncs it through Charm-sync.
	@server
]=]
local ResourceSyncService = setmetatable({}, { __index = BaseSyncService })
ResourceSyncService.__index = ResourceSyncService

-- Clones a wallet before storing or mutating it so callers never hold an atom reference.
local function cloneWallet(wallet: ResourceWallet): ResourceWallet
	return {
		energy = wallet.energy,
		resources = table.clone(wallet.resources),
		runStats = cloneRunStats(wallet.runStats),
	}
end

-- [Initialization]

--[=[
	Creates a new economy sync service.
	@within ResourceSyncService
	@return ResourceSyncService -- The new sync service.
]=]
function ResourceSyncService.new()
	local self = setmetatable({}, ResourceSyncService)
	self.AtomKey = "resources"
	self.BlinkEventName = "SyncResources"
	self.CreateAtom = SharedAtoms.CreateServerAtom
	return self
end

-- [Public API]

-- Loads the starting wallet for a player into the shared atom.
--[=[
	Initializes a player's wallet entry.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param startingWallet ResourceWallet -- The wallet to clone into the atom.
]=]
function ResourceSyncService:InitPlayer(userId: number, startingWallet: ResourceWallet)
	self:LoadUserData(userId, cloneWallet(startingWallet))
end

--[=[
	Updates the synced run-stats snapshot for a player's wallet.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param runStats ProfileRunStats -- The run stats snapshot to sync.
]=]
function ResourceSyncService:SyncRunStats(userId: number, runStats: ProfileRunStats)
	self.Atom(function(current)
		local wallet = current[userId]
		if wallet == nil then
			return current
		end

		local updated = table.clone(current)
		updated[userId] = cloneWallet(wallet)
		updated[userId].runStats = cloneRunStats(runStats)
		return updated
	end)
end

-- Adds a resource amount by cloning the wallet entry, mutating the copy, and writing it back.
-- The clone step is required so Charm sees a new reference and emits a sync patch.
--[=[
	Adds a resource amount to a player's wallet.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param resourceType string -- The resource to add.
	@param amount number -- The amount to add.
]=]
function ResourceSyncService:AddResource(userId: number, resourceType: string, amount: number)
	self.Atom(function(current)
		-- Leave uninitialized players untouched so the command layer can reject them explicitly.
		local wallet = current[userId]
		if wallet == nil then
			return current
		end

		-- Clone the atom root and the target wallet so Charm sees a new reference chain.
		local updated = table.clone(current)
		updated[userId] = cloneWallet(wallet)

		-- Apply the grant to the correct balance bucket.
		if resourceType == "Energy" then
			updated[userId].energy += amount
		else
			updated[userId].resources[resourceType] = (updated[userId].resources[resourceType] or 0) + amount
		end

		return updated
	end)
end

-- Subtracts a resource amount after the command layer has already validated affordability.
-- The method still clones the wallet so the atom mutation remains observable.
--[=[
	Subtracts a resource amount from a player's wallet.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param resourceType string -- The resource to subtract.
	@param cost number -- The amount to subtract.
]=]
function ResourceSyncService:SubtractResource(userId: number, resourceType: string, cost: number)
	self.Atom(function(current)
		-- Leave uninitialized players untouched so the command layer can reject them explicitly.
		local wallet = current[userId]
		if wallet == nil then
			return current
		end

		-- Clone the atom root and the target wallet so Charm sees a new reference chain.
		local updated = table.clone(current)
		updated[userId] = cloneWallet(wallet)

		-- Apply the deduction to the correct balance bucket.
		if resourceType == "Energy" then
			updated[userId].energy -= cost
		else
			updated[userId].resources[resourceType] = (updated[userId].resources[resourceType] or 0) - cost
		end

		return updated
	end)
end

--[=[
	Subtracts a validated multi-resource cost map from a player's wallet in one atom mutation.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param costMap ResourceCostMap -- Costs by resource type.
]=]
function ResourceSyncService:SubtractResources(userId: number, costMap: ResourceCostMap)
	self.Atom(function(current)
		local wallet = current[userId]
		if wallet == nil then
			return current
		end

		local updated = table.clone(current)
		updated[userId] = cloneWallet(wallet)

		for resourceType, cost in costMap do
			if resourceType == "Energy" then
				updated[userId].energy -= cost
			else
				updated[userId].resources[resourceType] = (updated[userId].resources[resourceType] or 0) - cost
			end
		end

		return updated
	end)
end

-- Returns a deep-cloned balance so callers cannot mutate the atom in place.
--[=[
	Reads a resource balance for a player.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param resourceType string -- The balance to read.
	@return number? -- The current balance, or `nil` if the player is uninitialized.
]=]
function ResourceSyncService:GetBalance(userId: number, resourceType: string): number?
	local wallet = self:GetReadOnly(userId)
	if wallet == nil then
		return nil
	end

	if resourceType == "Energy" then
		return wallet.energy
	end

	return wallet.resources[resourceType] or 0
end

--[=[
	Reads a deep-cloned wallet for a player.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@return ResourceWallet? -- The wallet clone, or `nil` if uninitialized.
]=]
function ResourceSyncService:GetWallet(userId: number): ResourceWallet?
	return self:GetReadOnly(userId)
end

--[=[
	Reads the current balances needed to validate a cost map.
	@within ResourceSyncService
	@param userId number -- The player user id.
	@param costMap ResourceCostMap -- Resource keys to read.
	@return ResourceCostMap? -- Current balances by requested resource type, or nil if uninitialized.
]=]
function ResourceSyncService:GetBalancesForCostMap(userId: number, costMap: ResourceCostMap): ResourceCostMap?
	local wallet = self:GetReadOnly(userId)
	if wallet == nil then
		return nil
	end

	local balances = {}
	for resourceType in costMap do
		if resourceType == "Energy" then
			balances[resourceType] = wallet.energy
		else
			balances[resourceType] = wallet.resources[resourceType] or 0
		end
	end

	return balances
end

-- Removes the player entry from the atom so the next run starts from a clean slate.
--[=[
	Removes a player's wallet entry.
	@within ResourceSyncService
	@param userId number -- The player user id.
]=]
function ResourceSyncService:RemovePlayer(userId: number)
	self:RemoveUserData(userId)
end

return ResourceSyncService
