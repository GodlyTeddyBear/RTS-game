--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local EconomyConfig = require(ReplicatedStorage.Contexts.Economy.Config.EconomyConfig)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

local BlinkServer = require(ReplicatedStorage.Network.Generated.ResourceSyncServer)

local ResourceValidator = require(script.Parent.EconomyDomain.Services.ResourceValidator)
local ResourceSyncService = require(script.Parent.Infrastructure.Persistence.ResourceSyncService)
local EconomyPersistenceService = require(script.Parent.Infrastructure.Persistence.EconomyPersistenceService)
local AddResourceCommand = require(script.Parent.Application.Commands.AddResourceCommand)
local SpendResourceCommand = require(script.Parent.Application.Commands.SpendResourceCommand)
local RecordWaveClearCommand = require(script.Parent.Application.Commands.RecordWaveClearCommand)
local RecordRunCompletedCommand = require(script.Parent.Application.Commands.RecordRunCompletedCommand)
local GetResourceBalanceQuery = require(script.Parent.Application.Queries.GetResourceBalanceQuery)
local GetResourceWalletQuery = require(script.Parent.Application.Queries.GetResourceWalletQuery)
local Errors = require(script.Parent.Errors)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

type ResourceWallet = EconomyTypes.ResourceWallet
type ProfileRunStats = EconomyTypes.ProfileRunStats
type RBXConnection = RBXScriptConnection

local Events = GameEvents.Events

local function createDefaultRunStats(): ProfileRunStats
	return {
		TotalRuns = 0,
		BestWave = 0,
		TotalWavesCleared = 0,
	}
end

local function normalizeRunStats(runStats: ProfileRunStats?): ProfileRunStats
	if not runStats then
		return createDefaultRunStats()
	end

	return {
		TotalRuns = runStats.TotalRuns or 0,
		BestWave = runStats.BestWave or 0,
		TotalWavesCleared = runStats.TotalWavesCleared or 0,
	}
end

local function shouldHaveActiveWallet(runState: string): boolean
	return runState ~= "Idle" and runState ~= "RunEnd"
end

--[=[
	@class EconomyContext
	Bridges the economy application stack to Run lifecycle events and public server APIs.
	@server
]=]
local EconomyContext = Knit.CreateService({
	Name = "EconomyContext",
	Client = {},
})

-- Registers the sync service, validator, commands, and queries before the context starts handling events.
--[=[
	Initializes the economy context dependencies.
	@within EconomyContext
]=]
function EconomyContext:KnitInit()
	-- Build the registry first so every downstream dependency can be resolved by name.
	local registry = Registry.new("Server")

	-- Register the sync layer before the application services that depend on it.
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("ResourceValidator", ResourceValidator.new(), "Domain")
	registry:Register("ResourceSyncService", ResourceSyncService.new(), "Infrastructure")
	registry:Register("EconomyPersistenceService", EconomyPersistenceService.new(), "Infrastructure")
	registry:Register("AddResourceCommand", AddResourceCommand.new(), "Application")
	registry:Register("SpendResourceCommand", SpendResourceCommand.new(), "Application")
	registry:Register("RecordWaveClearCommand", RecordWaveClearCommand.new(), "Application")
	registry:Register("RecordRunCompletedCommand", RecordRunCompletedCommand.new(), "Application")
	registry:Register("GetResourceBalanceQuery", GetResourceBalanceQuery.new(), "Application")
	registry:Register("GetResourceWalletQuery", GetResourceWalletQuery.new(), "Application")

	-- Run Init once all modules are registered so dependency lookups succeed.
	registry:InitAll()

	-- Cache resolved modules so the public API stays thin and deterministic.
	self._sync = registry:Get("ResourceSyncService")
	self._persistence = registry:Get("EconomyPersistenceService")
	self._addResourceCommand = registry:Get("AddResourceCommand")
	self._spendResourceCommand = registry:Get("SpendResourceCommand")
	self._recordWaveClearCommand = registry:Get("RecordWaveClearCommand")
	self._recordRunCompletedCommand = registry:Get("RecordRunCompletedCommand")
	self._getResourceBalanceQuery = registry:Get("GetResourceBalanceQuery")
	self._getResourceWalletQuery = registry:Get("GetResourceWalletQuery")

	self._runContext = nil :: any
	self._lastRewardedWaveNumber = nil :: number?
	self._runStateChangedConnection = nil :: any
	self._playerAddedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._profileLoadedConnection = nil :: RBXConnection?
	self._profileSavingConnection = nil :: RBXConnection?
	self._sessionRunStats = {} :: { [number]: ProfileRunStats }

	PlayerLifecycleManager:RegisterLoader("Economy")
end

-- Wires player lifecycle and run-state hooks after Knit has finished initializing all services.
--[=[
	Starts the economy context event wiring.
	@within EconomyContext
]=]
function EconomyContext:KnitStart()
	-- Resolve the run context once so event handlers can stay lightweight.
	self._runContext = Knit.GetService("RunContext")

	self._profileLoadedConnection = GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player: Player)
		self:_HandleProfileLoaded(player)
	end)

	self._profileSavingConnection = GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(_player: Player) end)

	-- Hydrate players that join after EconomyContext starts listening.
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self:_EnsureWalletForActiveRun(player)
		self._sync:HydratePlayer(player)
	end)

	-- Hydrate players already present so they see the current wallet state immediately.
	for _, player in Players:GetPlayers() do
		self:_EnsureWalletForActiveRun(player)
		self._sync:HydratePlayer(player)
	end

	-- Remove wallet entries as soon as players leave the server.
	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self._sync:RemovePlayer(player.UserId)
		self._sessionRunStats[player.UserId] = nil
	end)

	-- Bridge run lifecycle changes into the economy state transitions.
	self._runStateChangedConnection = self._runContext.StateChanged:Connect(function(newState: string, previousState: string)
		self:_OnRunStateChanged(newState, previousState)
	end)

	-- Backfill players whose profile loaded before this context subscribed.
	for _, player in Players:GetPlayers() do
		if ProfileManager:Has(player) then
			self:_HandleProfileLoaded(player)
		end
	end
end

function EconomyContext:_EnsureWalletForActiveRun(player: Player)
	local runStateResult = self._runContext:GetState()
	if not runStateResult.success then
		return
	end

	if not shouldHaveActiveWallet(runStateResult.value) then
		return
	end

	if self._sync:GetWallet(player.UserId) ~= nil then
		return
	end

	self._sync:InitPlayer(player.UserId, EconomyConfig.STARTING_WALLET)
	self._sync:SyncRunStats(player.UserId, self._sessionRunStats[player.UserId] or createDefaultRunStats())
end

-- Handles profile hydration for the persistence lifecycle and signals loader readiness.
function EconomyContext:_HandleProfileLoaded(player: Player)
	local loadResult = self._persistence:LoadRunStatsData(player)
	if loadResult.success then
		self._sessionRunStats[player.UserId] = normalizeRunStats(loadResult.value)
	else
		Result.MentionError("Economy:ProfileLoaded", "Failed to load persisted run stats; using defaults", {
			PlayerUserId = player.UserId,
			CauseType = loadResult.type,
			CauseMessage = loadResult.message,
		}, loadResult.type)
		self._sessionRunStats[player.UserId] = createDefaultRunStats()
	end

	if self._sync:GetWallet(player.UserId) ~= nil then
		self._sync:SyncRunStats(player.UserId, self._sessionRunStats[player.UserId])
	end

	PlayerLifecycleManager:NotifyLoaded(player, "Economy")
end

-- Handles run lifecycle transitions so wallet resets and rewards stay centralized here.
function EconomyContext:_OnRunStateChanged(newState: string, previousState: string)
	-- Prep is the authoritative run start when entered from lobby terminal states.
	if newState == "Prep" and (previousState == "Idle" or previousState == "RunEnd") then
		self._lastRewardedWaveNumber = nil
		for _, player in Players:GetPlayers() do
			self._sync:InitPlayer(player.UserId, EconomyConfig.STARTING_WALLET)
			self._sync:SyncRunStats(player.UserId, self._sessionRunStats[player.UserId] or createDefaultRunStats())
		end
		return
	end

	-- Resolution grants the wave-clear reward once, after combat finishes and before the next phase.
	if newState == "Resolution" then
		local waveNumberResult = self._runContext:GetWaveNumber()
		if not waveNumberResult.success then
			Result.MentionError("Economy:OnRunResolutionReward", "Unable to read current wave number", {
				CauseType = waveNumberResult.type,
				CauseMessage = waveNumberResult.message,
			}, waveNumberResult.type)
			return
		end

		local waveNumber = waveNumberResult.value
		if self._lastRewardedWaveNumber == waveNumber then
			return
		end

		self._lastRewardedWaveNumber = waveNumber
		for _, player in Players:GetPlayers() do
			Catch(function()
				Try(self._addResourceCommand:Execute(player.UserId, "Energy", EconomyConfig.WAVE_CLEAR_BONUS))
				return Ok(nil)
			end, "Economy:OnRunResolutionReward")

			local recordResult = self._recordWaveClearCommand:Execute(player, waveNumber)
			if recordResult.success then
				self._sessionRunStats[player.UserId] = recordResult.value
			else
				Result.MentionError("Economy:RecordWaveClear", "Failed to persist wave-clear run stats; applying in-memory fallback", {
					PlayerUserId = player.UserId,
					CauseType = recordResult.type,
					CauseMessage = recordResult.message,
				}, recordResult.type)
				local runStats = self._sessionRunStats[player.UserId] or createDefaultRunStats()
				runStats.BestWave = math.max(runStats.BestWave, waveNumber)
				runStats.TotalWavesCleared += 1
				self._sessionRunStats[player.UserId] = runStats
				self._sync:SyncRunStats(player.UserId, runStats)
			end
		end
		return
	end

	-- RunEnd clears all wallet entries so the next run starts from a clean atom state.
	if newState == "RunEnd" then
		for _, player in Players:GetPlayers() do
			local recordResult = self._recordRunCompletedCommand:Execute(player)
			if recordResult.success then
				self._sessionRunStats[player.UserId] = recordResult.value
			else
				Result.MentionError("Economy:RecordRunCompleted", "Failed to persist completed-run stats; applying in-memory fallback", {
					PlayerUserId = player.UserId,
					CauseType = recordResult.type,
					CauseMessage = recordResult.message,
				}, recordResult.type)
				local runStats = self._sessionRunStats[player.UserId] or createDefaultRunStats()
				runStats.TotalRuns += 1
				self._sessionRunStats[player.UserId] = runStats
				self._sync:SyncRunStats(player.UserId, runStats)
			end

			self._sync:RemovePlayer(player.UserId)
		end
	end
end

--[=[
	Reads a player's current balance for a resource type.
	@within EconomyContext
	@param player Player -- The player whose balance should be read.
	@param resourceType string -- The resource to read.
	@return Result.Result<number?> -- The current balance, or `nil` if uninitialized.
]=]
function EconomyContext:GetBalance(player: Player, resourceType: string): Result.Result<number?>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return Ok(self._getResourceBalanceQuery:Execute(player.UserId, resourceType))
	end, "Economy:GetBalance")
end

--[=[
	Reads a player's full economy wallet.
	@within EconomyContext
	@param player Player -- The player whose wallet should be read.
	@return Result.Result<ResourceWallet?> -- The cloned wallet, or `nil` if uninitialized.
]=]
function EconomyContext:GetWallet(player: Player): Result.Result<ResourceWallet?>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return Ok(self._getResourceWalletQuery:Execute(player.UserId))
	end, "Economy:GetWallet")
end

--[=[
	Reads a player's energy balance.
	@within EconomyContext
	@param player Player -- The player whose energy should be read.
	@return Result.Result<number?> -- The current energy balance, or `nil` if uninitialized.
]=]
function EconomyContext:GetEnergy(player: Player): Result.Result<number?>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return Ok(self._getResourceBalanceQuery:Execute(player.UserId, "Energy"))
	end, "Economy:GetEnergy")
end

--[=[
	Adds a resource to a player's wallet.
	@within EconomyContext
	@param player Player -- The player receiving the resource.
	@param resourceType string -- The resource to add.
	@param amount number -- The amount to add.
	@return Result.Result<nil> -- `Ok(nil)` when the grant succeeds.
]=]
function EconomyContext:AddResource(player: Player, resourceType: string, amount: number): Result.Result<nil>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return self._addResourceCommand:Execute(player.UserId, resourceType, amount)
	end, "Economy:AddResource")
end

--[=[
	Spends a resource from a player's wallet.
	@within EconomyContext
	@param player Player -- The player spending the resource.
	@param resourceType string -- The resource to spend.
	@param cost number -- The amount to spend.
	@return Result.Result<nil> -- `Ok(nil)` when the spend succeeds.
]=]
function EconomyContext:SpendResource(player: Player, resourceType: string, cost: number): Result.Result<nil>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return self._spendResourceCommand:Execute(player.UserId, resourceType, cost)
	end, "Economy:SpendResource")
end

--[=[
	Spends energy from a player's wallet.
	@within EconomyContext
	@param player Player -- The player spending energy.
	@param cost number -- The amount to spend.
	@return Result.Result<nil> -- `Ok(nil)` when the spend succeeds.
]=]
function EconomyContext:SpendEnergy(player: Player, cost: number): Result.Result<nil>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return self._spendResourceCommand:Execute(player.UserId, "Energy", cost)
	end, "Economy:SpendEnergy")
end

--[=[
	Applies a pickup or drop grant to a player's wallet.
	@within EconomyContext
	@param player Player -- The player receiving the grant.
	@param grant { resourceType: string, amount: number } -- The grant payload.
	@return Result.Result<nil> -- `Ok(nil)` when the grant succeeds.
]=]
function EconomyContext:AddPickupGrant(player: Player, grant: { resourceType: string, amount: number }): Result.Result<nil>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(grant, "InvalidGrant", Errors.INVALID_GRANT)
		Ensure(grant.resourceType, "InvalidGrant", Errors.INVALID_GRANT_RESOURCE_TYPE)
		Ensure(grant.amount, "InvalidGrant", Errors.INVALID_GRANT_AMOUNT)
		return self._addResourceCommand:Execute(player.UserId, grant.resourceType, grant.amount)
	end, "Economy:AddPickupGrant")
end

--[=[
	Disconnects lifecycle listeners.
	@within EconomyContext
]=]
function EconomyContext:Destroy()
	-- Shut down the sync service first so no more atom updates are emitted during teardown.
	if self._sync then
		self._sync:Destroy()
	end

	if self._runStateChangedConnection then
		self._runStateChangedConnection:Disconnect()
	end
	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
	end
	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
	end
	if self._profileLoadedConnection then
		self._profileLoadedConnection:Disconnect()
	end
	if self._profileSavingConnection then
		self._profileSavingConnection:Disconnect()
	end
end

WrapContext(EconomyContext, "Economy")

return EconomyContext
