--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Result = require(ReplicatedStorage.Utilities.Result)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch, Try, Ok = Result.Catch, Result.Try, Result.Ok
local MentionSuccess = Result.MentionSuccess
local BlinkServer = require(ReplicatedStorage.Network.Generated.BuildingSyncServer)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)

-- ECS Infrastructure
local ECSWorldService = require(script.Parent.Infrastructure.ECS.ECSWorldService)
local ComponentRegistry = require(script.Parent.Infrastructure.ECS.ComponentRegistry)
local BuildingEntityFactory = require(script.Parent.Infrastructure.ECS.BuildingEntityFactory)

-- Persistence Infrastructure
local BuildingModelSyncService = require(script.Parent.Infrastructure.Persistence.BuildingModelSyncService)
local BuildingPersistenceService = require(script.Parent.Infrastructure.Persistence.BuildingPersistenceService)
local BuildingSyncService = require(script.Parent.Infrastructure.Persistence.BuildingSyncService)
local MachineRuntimeStore = require(script.Parent.Infrastructure.Persistence.MachineRuntimeStore)
local MachineProcessService = require(script.Parent.Infrastructure.Services.MachineProcessService)

-- Infrastructure Services
local BuildingModelFactory = require(script.Parent.Infrastructure.Services.BuildingModelFactory)
local BuildingCurrencyService = require(script.Parent.Infrastructure.Services.BuildingCurrencyService)
local BuildingRevealAdapter = require(script.Parent.Infrastructure.Reveal.BuildingRevealAdapter)

-- Domain Policies
local ConstructPolicy = require(script.Parent.BuildingDomain.Policies.ConstructPolicy)
local UpgradePolicy = require(script.Parent.BuildingDomain.Policies.UpgradePolicy)

-- Application Commands / Queries
local ConstructBuilding = require(script.Parent.Application.Commands.ConstructBuilding)
local UpgradeBuilding = require(script.Parent.Application.Commands.UpgradeBuilding)
local RestoreBuildings = require(script.Parent.Application.Commands.RestoreBuildings)
local GetLotBuildings = require(script.Parent.Application.Queries.GetLotBuildings)
local GetMachineState = require(script.Parent.Application.Queries.GetMachineState)
local MachineAddFuel = require(script.Parent.Application.Commands.MachineAddFuel)
local MachineQueueRecipe = require(script.Parent.Application.Commands.MachineQueueRecipe)
local MachineClaimOutput = require(script.Parent.Application.Commands.MachineClaimOutput)

--[=[
	@class BuildingContext
	Coordinates building construction, upgrades, machine actions, and sync orchestration.
	@server
]=]
local BuildingContext = Knit.CreateService({
	Name = "BuildingContext",
	Client = {},
})

--[=[
	Initialize registry wiring for infrastructure, domain, and application services.
	@within BuildingContext
]=]
function BuildingContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	local ecsWorldService = ECSWorldService.new()

	-- Shared state
	local buildingIdCounter = { Value = 0 }

	-- Register raw values
	registry:Register("BuildingECSWorldService", ecsWorldService, "Infrastructure")
	registry:Register("ProfileManager", ProfileManager, "Infrastructure")
	registry:Register("BuildingIdCounter", buildingIdCounter)
	registry:Register("BlinkServer", BlinkServer)

	-- Infrastructure
	registry:Register("BuildingComponentRegistry", ComponentRegistry.new(), "Infrastructure")
	registry:Register("BuildingEntityFactory", BuildingEntityFactory.new(), "Infrastructure")
	registry:Register("BuildingModelFactory", BuildingModelFactory.new(), "Infrastructure")
	registry:Register("BuildingRevealAdapter", BuildingRevealAdapter.new(), "Infrastructure")
	registry:Register("BuildingPersistenceService", BuildingPersistenceService.new(), "Infrastructure")
	registry:Register("BuildingCurrencyService", BuildingCurrencyService.new(), "Infrastructure")
	registry:Register("BuildingModelSyncService", BuildingModelSyncService.new(), "Infrastructure")
	registry:Register("BuildingSyncService", BuildingSyncService.new(), "Infrastructure")
	registry:Register("MachineRuntimeStore", MachineRuntimeStore.new(), "Infrastructure")

	-- Domain
	registry:Register("ConstructPolicy", ConstructPolicy.new(), "Domain")
	registry:Register("UpgradePolicy", UpgradePolicy.new(), "Domain")

	-- Application
	registry:Register("ConstructBuilding", ConstructBuilding.new(buildingIdCounter), "Application")
	registry:Register("UpgradeBuilding", UpgradeBuilding.new(), "Application")
	registry:Register("RestoreBuildings", RestoreBuildings.new(buildingIdCounter), "Application")
	registry:Register("GetLotBuildings", GetLotBuildings.new(), "Application")
	registry:Register("GetMachineState", GetMachineState.new(), "Application")
	registry:Register("MachineAddFuel", MachineAddFuel.new(), "Application")
	registry:Register("MachineQueueRecipe", MachineQueueRecipe.new(), "Application")
	registry:Register("MachineClaimOutput", MachineClaimOutput.new(), "Application")

	registry:InitAll()

	-- Cache refs
	self.EntityFactory = registry:Get("BuildingEntityFactory")
	self.SyncService = registry:Get("BuildingModelSyncService")
	self.BuildingSyncService = registry:Get("BuildingSyncService")
	self.PersistenceService = registry:Get("BuildingPersistenceService")
	self.ConstructBuildingCommand = registry:Get("ConstructBuilding")
	self.UpgradeBuildingCommand = registry:Get("UpgradeBuilding")
	self.RestoreBuildingsCommand = registry:Get("RestoreBuildings")
	self.GetLotBuildingsQuery = registry:Get("GetLotBuildings")
	self.GetMachineStateQuery = registry:Get("GetMachineState")
	self.MachineAddFuelCommand = registry:Get("MachineAddFuel")
	self.MachineQueueRecipeCommand = registry:Get("MachineQueueRecipe")
	self.MachineClaimOutputCommand = registry:Get("MachineClaimOutput")
	self.MachineRuntimeStore = registry:Get("MachineRuntimeStore")
	self.BuildingIdCounter = buildingIdCounter
end

--[=[
	Start cross-context integrations, runtime systems, and player lifecycle hooks.
	@within BuildingContext
]=]
function BuildingContext:KnitStart()
	-- Cross-context: give SyncService access to LotContext for zone folder lookups
	local lotContext = Knit.GetService("LotContext")
	self.SyncService:SetLotContext(lotContext)

	local inventoryContext = Knit.GetService("InventoryContext")
	local unlockContext = Knit.GetService("UnlockContext")
	self.Registry:Register("InventoryContext", inventoryContext)
	self.Registry:Register("UnlockContext", unlockContext)
	self.Registry:StartOrdered({ "Domain", "Application" })

	self.MachineProcessService = MachineProcessService.new(self.MachineRuntimeStore, self.PersistenceService)

	-- Register ECS sync system with the Planck scheduler
	ServerScheduler:RegisterSystem(function()
		self.SyncService:SyncDirtyEntities()
		return nil
	end, "BuildingSync")

	ServerScheduler:RegisterSystem(function()
		self.MachineProcessService:TickAllPlayers()
		return nil
	end, "MachineRuntime")

	-- Restore buildings after the lot is spawned and zone folders exist in workspace
	GameEvents.Bus:On(GameEvents.Events.Lot.LotSpawned, function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			warn("No player", player)
			return
		end
		self:_RestorePlayerBuildings(player)
		self:_HydratePlayerBuildingSync(player)
		GameEvents.Bus:Emit(Events.Building.RestoreCompleted, userId)
	end)

	-- Clean up buildings when a player leaves
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_CleanupPlayerBuildings(player)
		self.BuildingSyncService:RemovePlayerBuildings(player.UserId)
	end)
end

--[=[
	Construct a building in a zone slot and refresh synced slot state when successful.
	@within BuildingContext
	@param player Player -- Player requesting construction.
	@param zoneName string -- Zone name, for example `Forge` or `Farm`.
	@param slotIndex number -- One-based slot index within the zone.
	@param buildingType string -- Building type key from config.
	@return Result.Result<string> -- Result containing the created building ID on success.
]=]
function BuildingContext:ConstructBuilding(
	player: Player,
	zoneName: string,
	slotIndex: number,
	buildingType: string
): Result.Result<string>
	-- Execute policy-validated construction through the application command.
	local result = self.ConstructBuildingCommand:Execute(player, zoneName, slotIndex, buildingType)

	-- Push authoritative slot data to the client only after successful construction.
	if result.success then
		self.BuildingSyncService:SetSlot(player.UserId, zoneName, slotIndex, buildingType, 1)
		self.BuildingSyncService:HydratePlayer(player)
	end

	-- Return the domain result unchanged for caller-level error handling.
	return result
end

--[=[
	Upgrade an existing building and sync the latest slot level when successful.
	@within BuildingContext
	@param player Player -- Player requesting the upgrade.
	@param zoneName string -- Zone containing the target slot.
	@param slotIndex number -- One-based slot index within the zone.
	@return Result.Result<nil> -- Result indicating whether the upgrade succeeded.
]=]
function BuildingContext:UpgradeBuilding(player: Player, zoneName: string, slotIndex: number): Result.Result<nil>
	-- Execute upgrade rules and persistence updates through the command layer.
	local result = self.UpgradeBuildingCommand:Execute(player, zoneName, slotIndex)

	-- Mirror the persisted slot level into replicated building state after success.
	if result.success then
		local slotData = self.PersistenceService:GetSlotData(player, zoneName, slotIndex)
		if slotData then
			self.BuildingSyncService:SetSlot(player.UserId, zoneName, slotIndex, slotData.BuildingType, slotData.Level)
			self.BuildingSyncService:HydratePlayer(player)
		end
	end

	-- Return the command result so callers receive precise failure details.
	return result
end

--[=[
	Get all persisted and restored building entries for a player's lot.
	@within BuildingContext
	@param player Player -- Player whose lot snapshot is requested.
	@return any -- Lot building query result payload.
]=]
function BuildingContext:GetBuildings(player: Player)
	return self.GetLotBuildingsQuery:Execute(player)
end

--[=[
	Check whether a player currently has at least one instance of the requested building type in a zone.
	@within BuildingContext
	@param userId number -- User ID whose building state should be checked.
	@param zoneName string -- Zone to inspect, for example `Forge`.
	@param buildingType string -- Building type key to search for.
	@return boolean -- True when any slot in the zone contains the building type.
]=]
function BuildingContext:HasBuildingForUser(userId: number, zoneName: string, buildingType: string): boolean
	local buildingMap = self.BuildingSyncService:GetBuildingsReadOnly(userId)
	if not buildingMap then
		return false
	end

	local zoneSlots = buildingMap[zoneName]
	if not zoneSlots then
		return false
	end

	for _, slotData in zoneSlots do
		if slotData and slotData.BuildingType == buildingType then
			return true
		end
	end

	return false
end

--[=[
	Get machine runtime state for a specific zone slot.
	@within BuildingContext
	@param player Player -- Player that owns the machine slot.
	@param zoneName string -- Zone containing the machine.
	@param slotIndex number -- One-based slot index for the machine.
	@return Result.Result<any> -- Result with machine runtime snapshot data.
]=]
function BuildingContext:GetMachineState(player: Player, zoneName: string, slotIndex: number): Result.Result<any>
	return Catch(function()
		return Try(self.GetMachineStateQuery:Execute(player, zoneName, slotIndex))
	end, "BuildingContext:GetMachineState")
end

--[=[
	Add fuel to a machine queue in the selected zone slot.
	@within BuildingContext
	@param player Player -- Player requesting the fuel action.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@param quantity number -- Number of fuel units to consume.
	@return Result.Result<nil> -- Result indicating whether fuel was added.
]=]
function BuildingContext:MachineAddFuel(
	player: Player,
	zoneName: string,
	slotIndex: number,
	quantity: number
): Result.Result<nil>
	return Catch(function()
		Try(self.MachineAddFuelCommand:Execute(player, zoneName, slotIndex, quantity))
		return Ok(nil)
	end, "BuildingContext:MachineAddFuel")
end

--[=[
	Queue a recipe on a machine in the selected zone slot.
	@within BuildingContext
	@param player Player -- Player requesting the queue action.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@param recipeId string -- Recipe identifier to enqueue.
	@return Result.Result<nil> -- Result indicating whether the recipe was queued.
]=]
function BuildingContext:MachineQueueRecipe(
	player: Player,
	zoneName: string,
	slotIndex: number,
	recipeId: string
): Result.Result<nil>
	return Catch(function()
		Try(self.MachineQueueRecipeCommand:Execute(player, zoneName, slotIndex, recipeId))
		return Ok(nil)
	end, "BuildingContext:MachineQueueRecipe")
end

--[=[
	Claim completed machine output from the selected zone slot.
	@within BuildingContext
	@param player Player -- Player requesting output claim.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@return Result.Result<nil> -- Result indicating whether output was claimed.
]=]
function BuildingContext:MachineClaimOutput(player: Player, zoneName: string, slotIndex: number): Result.Result<nil>
	return Catch(function()
		Try(self.MachineClaimOutputCommand:Execute(player, zoneName, slotIndex))
		return Ok(nil)
	end, "BuildingContext:MachineClaimOutput")
end

-- Load a player's persisted buildings into sync atoms so the client starts from authoritative state.
function BuildingContext:_HydratePlayerBuildingSync(player: Player)
	local _ = Catch(function()
		-- Fetch the persisted building snapshot for this player.
		local buildings = self.PersistenceService:GetAllBuildings(player)

		-- Seed sync state before hydrating so clients receive the full snapshot.
		self.BuildingSyncService:LoadPlayerBuildings(player.UserId, buildings or {})
		self.BuildingSyncService:HydratePlayer(player)
		return nil
	end, "BuildingContext:_HydratePlayerBuildingSync")
	return nil
end

-- Restore ECS building entities after lot spawn so world models and persistence re-align on join.
function BuildingContext:_RestorePlayerBuildings(player: Player)
	local _ = Catch(function()
		local existingEntities = self.EntityFactory:FindBuildingsByUser(player.UserId)
		local existingCount = #existingEntities

		-- Recreate entities from persisted player data.
		Try(self.RestoreBuildingsCommand:Execute(player))
		local restoredEntities = self.EntityFactory:FindBuildingsByUser(player.UserId)
		local restoredCount = #restoredEntities

		-- Flush dirty entities so models appear immediately.
		self.SyncService:SyncDirtyEntities()
		local unresolvedDirtyCount = 0
		for entity in self.SyncService._world:query(self.SyncService._components.DirtyTag) do
			local buildingData = self.EntityFactory:GetBuildingData(entity)
			if buildingData and buildingData.UserId == player.UserId then
				unresolvedDirtyCount += 1
			end
		end

		MentionSuccess("BuildingContext:_RestorePlayerBuildings", "Restore pipeline completed for player", {
			userId = player.UserId,
			existingEntityCount = existingCount,
			restoredEntityCount = restoredCount,
			unresolvedDirtyCount = unresolvedDirtyCount,
		})
		return nil
	end, "BuildingContext:_RestorePlayerBuildings")
	return nil
end

-- Remove all ECS entities and models for a departing player to prevent orphaned world objects.
function BuildingContext:_CleanupPlayerBuildings(player: Player)
	self.SyncService:DeleteAllForUser(player.UserId)
end

-- Client API

--[=[
	Forward a construction request from client to server context logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone where construction should occur.
	@param slotIndex number -- One-based slot index within the zone.
	@param buildingType string -- Building type key from config.
	@return Result.Result<string> -- Construction result from server execution.
]=]
function BuildingContext.Client:ConstructBuilding(
	player: Player,
	zoneName: string,
	slotIndex: number,
	buildingType: string
)
	return self.Server:ConstructBuilding(player, zoneName, slotIndex, buildingType)
end

--[=[
	Forward an upgrade request from client to server context logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone containing the building slot.
	@param slotIndex number -- One-based slot index to upgrade.
	@return Result.Result<nil> -- Upgrade result from server execution.
]=]
function BuildingContext.Client:UpgradeBuilding(player: Player, zoneName: string, slotIndex: number)
	return self.Server:UpgradeBuilding(player, zoneName, slotIndex)
end

--[=[
	Forward a lot building snapshot request from client to server query logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@return any -- Building snapshot payload returned by server query.
]=]
function BuildingContext.Client:GetBuildings(player: Player)
	return self.Server:GetBuildings(player)
end

--[=[
	Forward a machine state request from client to server query logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@return Result.Result<any> -- Machine state result from server execution.
]=]
function BuildingContext.Client:GetMachineState(player: Player, zoneName: string, slotIndex: number)
	return self.Server:GetMachineState(player, zoneName, slotIndex)
end

--[=[
	Forward a machine fuel request from client to server command logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@param quantity number -- Number of fuel units to add.
	@return Result.Result<nil> -- Fuel command result from server execution.
]=]
function BuildingContext.Client:MachineAddFuel(player: Player, zoneName: string, slotIndex: number, quantity: number)
	return self.Server:MachineAddFuel(player, zoneName, slotIndex, quantity)
end

--[=[
	Forward a recipe queue request from client to server command logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@param recipeId string -- Recipe identifier to queue.
	@return Result.Result<nil> -- Queue command result from server execution.
]=]
function BuildingContext.Client:MachineQueueRecipe(player: Player, zoneName: string, slotIndex: number, recipeId: string)
	return self.Server:MachineQueueRecipe(player, zoneName, slotIndex, recipeId)
end

--[=[
	Forward an output claim request from client to server command logic.
	@within BuildingContext
	@param player Player -- Calling player supplied by Knit.
	@param zoneName string -- Zone containing the target machine.
	@param slotIndex number -- One-based slot index for the machine.
	@return Result.Result<nil> -- Claim command result from server execution.
]=]
function BuildingContext.Client:MachineClaimOutput(player: Player, zoneName: string, slotIndex: number)
	return self.Server:MachineClaimOutput(player, zoneName, slotIndex)
end

WrapContext(BuildingContext, "BuildingContext")

return BuildingContext
