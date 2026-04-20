--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local BlinkServer = require(ReplicatedStorage.Network.Generated.WorkerSyncServer)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)

local Players = game:GetService("Players")

local Catch = Result.Catch
local Err = Result.Err

-- ECS Infrastructure
local ECSWorldService = require(script.Parent.Infrastructure.ECS.ECSWorldService)
local ComponentRegistry = require(script.Parent.Infrastructure.ECS.ComponentRegistry)
local WorkerEntityFactory = require(script.Parent.Infrastructure.ECS.WorkerEntityFactory)

-- Persistence Infrastructure
local GameObjectSyncService = require(script.Parent.Infrastructure.Persistence.GameObjectSyncService)
local WorkerSyncService = require(script.Parent.Infrastructure.Persistence.WorkerSyncService)
local WorkerPersistenceService = require(script.Parent.Infrastructure.Persistence.WorkerPersistenceService)

-- Infrastructure Services
local GameObjectFactory = require(script.Parent.Infrastructure.Services.GameObjectFactory)
local EquipmentService = require(script.Parent.Infrastructure.Services.EquipmentService)
local MiningSlotService = require(script.Parent.Infrastructure.Services.MiningSlotService)
local ForestSlotService = require(script.Parent.Infrastructure.Services.ForestSlotService)
local GardenSlotService = require(script.Parent.Infrastructure.Services.GardenSlotService)
local ForgeStationSlotService = require(script.Parent.Infrastructure.Services.ForgeStationSlotService)
local BreweryStationSlotService = require(script.Parent.Infrastructure.Services.BreweryStationSlotService)
local UndecidedSpawnService = require(script.Parent.Infrastructure.Services.UndecidedSpawnService)
local WorkerRevealAdapter = require(script.Parent.Infrastructure.Reveal.WorkerRevealAdapter)

-- Domain Services
local WorkerLevelService = require(script.Parent.WorkerDomain.Services.WorkerLevelService)
local MiningSlotCalculator = require(script.Parent.WorkerDomain.Services.MiningSlotCalculator)
local ForestSlotCalculator = require(script.Parent.WorkerDomain.Services.ForestSlotCalculator)
local GardenSlotCalculator = require(script.Parent.WorkerDomain.Services.GardenSlotCalculator)
local ForgeStationSlotCalculator = require(script.Parent.WorkerDomain.Services.ForgeStationSlotCalculator)
local BreweryStationSlotCalculator = require(script.Parent.WorkerDomain.Services.BreweryStationSlotCalculator)

-- Domain Policies
local HirePolicy = require(script.Parent.WorkerDomain.Policies.HirePolicy)
local AssignRolePolicy = require(script.Parent.WorkerDomain.Policies.AssignRolePolicy)
local AssignMinerOrePolicy = require(script.Parent.WorkerDomain.Policies.AssignMinerOrePolicy)
local AssignForgeRecipePolicy = require(script.Parent.WorkerDomain.Policies.AssignForgeRecipePolicy)
local AssignBreweryRecipePolicy = require(script.Parent.WorkerDomain.Policies.AssignBreweryRecipePolicy)
local MiningTickPolicy = require(script.Parent.WorkerDomain.Policies.MiningTickPolicy)
local ForgeTickPolicy = require(script.Parent.WorkerDomain.Policies.ForgeTickPolicy)
local BreweryTickPolicy = require(script.Parent.WorkerDomain.Policies.BreweryTickPolicy)
local ProductionEligibilityPolicy = require(script.Parent.WorkerDomain.Policies.ProductionEligibilityPolicy)

-- New role policies (disabled until lot zones are implemented)
local AssignTailoringRecipePolicy = require(script.Parent.WorkerDomain.Policies.AssignTailoringRecipePolicy)
local AssignLumberjackTargetPolicy = require(script.Parent.WorkerDomain.Policies.AssignLumberjackTargetPolicy)
local AssignHerbalistTargetPolicy = require(script.Parent.WorkerDomain.Policies.AssignHerbalistTargetPolicy)
local AssignFarmerTargetPolicy = require(script.Parent.WorkerDomain.Policies.AssignFarmerTargetPolicy)
local TailorTickPolicy = require(script.Parent.WorkerDomain.Policies.TailorTickPolicy)
local HarvestTickPolicy = require(script.Parent.WorkerDomain.Policies.HarvestTickPolicy)

-- Application Services
local HireWorker = require(script.Parent.Application.Commands.HireWorker)
local AssignWorkerRole = require(script.Parent.Application.Commands.AssignWorkerRole)
local AssignMinerOre = require(script.Parent.Application.Commands.AssignMinerOre)
local AssignForgeRecipe = require(script.Parent.Application.Commands.AssignForgeRecipe)
local AssignBreweryRecipe = require(script.Parent.Application.Commands.AssignBreweryRecipe)
local ProcessWorkerProduction = require(script.Parent.Application.Commands.ProcessWorkerProduction)
local ProcessMinerMining = require(script.Parent.Application.Commands.ProcessMinerMining)

-- New roles (disabled until lot zones are implemented)
local AssignTailoringRecipe = require(script.Parent.Application.Commands.AssignTailoringRecipe)
local AssignLumberjackTarget = require(script.Parent.Application.Commands.AssignLumberjackTarget)
local AssignHerbalistTarget = require(script.Parent.Application.Commands.AssignHerbalistTarget)
local AssignFarmerTarget = require(script.Parent.Application.Commands.AssignFarmerTarget)
local ProcessHarvesting = require(script.Parent.Application.Commands.ProcessHarvesting)

-- Configs used by hydration
local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local PlantConfig = require(ReplicatedStorage.Contexts.Worker.Config.PlantConfig)
local TreeConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeConfig)
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)

type THydrationRoleConfig = {
	PolicyField: string,
	ResultInstanceKey: string?,
	DurationConfig: { [string]: any },
	DurationField: string,
	SlotServiceField: string?,
	RequireModelForSlot: boolean?,
	AnimationState: string?,
}

local HYDRATION_ROLE_CONFIG: { [string]: THydrationRoleConfig } = {
	Miner = {
		PolicyField = "AssignMinerOrePolicy",
		ResultInstanceKey = "OreInstance",
		DurationConfig = OreConfig,
		DurationField = "MiningDuration",
		SlotServiceField = "MiningSlotService",
	},
	Lumberjack = {
		PolicyField = "AssignLumberjackTargetPolicy",
		ResultInstanceKey = "TreeInstance",
		DurationConfig = TreeConfig,
		DurationField = "ChopDuration",
		SlotServiceField = "ForestSlotService",
		RequireModelForSlot = true,
		AnimationState = "Chopping",
	},
	Herbalist = {
		PolicyField = "AssignHerbalistTargetPolicy",
		ResultInstanceKey = "PlantInstance",
		DurationConfig = PlantConfig,
		DurationField = "HarvestDuration",
		SlotServiceField = "GardenSlotService",
		RequireModelForSlot = true,
	},
	Forge = {
		PolicyField = "AssignForgeRecipePolicy",
		ResultInstanceKey = "ForgeStationInstance",
		DurationConfig = RecipeConfig,
		DurationField = "NoDurationField",
		SlotServiceField = "ForgeStationSlotService",
	},
	Brewery = {
		PolicyField = "AssignBreweryRecipePolicy",
		ResultInstanceKey = "BreweryStationInstance",
		DurationConfig = BreweryRecipeConfig,
		DurationField = "NoDurationField",
		SlotServiceField = "BreweryStationSlotService",
	},
}

-- Shared types
local WorkerTypes = require(ReplicatedStorage.Contexts.Worker.Types.WorkerTypes)
type TWorker = WorkerTypes.TWorker

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

--[=[
	@class WorkerContext
	Knit service that owns the Worker bounded context. Manages the full worker lifecycle:
	player join/leave loading, ECS entity hydration, production tick registration, and
	all client/cross-context API methods.

	:::note
	Worker entities are created in two passes after `Building.RestoreCompleted`: first all entities are
	spawned at the origin, then `SyncDirtyEntities` is flushed, and finally slot
	claim + teleport + action-start runs for each assigned worker.
	:::
	@server
]=]
local WorkerContext = Knit.CreateService({
	Name = "WorkerContext",
	Client = {},
	_PendingWorkerData = {} :: { [number]: { [string]: any } },
})

---
--- Knit Lifecycle
---

function WorkerContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- ECS World: create world service, extract world, register both
	local ecsWorldService = ECSWorldService.new()
	local world = ecsWorldService:GetWorld()
	registry:Register("ECSWorldService", ecsWorldService)
	registry:Register("World", world)

	-- Asset registries
	local workersFolder = ReplicatedStorage.Assets.Entities.Workers
	local workerRegistry = AssetFetcher.CreateWorkerRegistry(workersFolder)
	local animationsFolder = ReplicatedStorage.Assets.Animations

	-- EquipmentService (depends on toolRegistry)
	local toolsFolder = ReplicatedStorage.Assets.Items.Tools
	local toolRegistry = AssetFetcher.CreateToolRegistry(toolsFolder)
	local equipmentService = EquipmentService.new(toolRegistry)

	-- Raw value registrations
	registry:Register("WorkerRegistry", workerRegistry)
	registry:Register("EquipmentService", equipmentService)
	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("WorkerContext")

	-- Domain Services
	registry:Register("WorkerLevelService", WorkerLevelService.new(), "Domain")
	registry:Register("MiningSlotCalculator", MiningSlotCalculator.new(), "Domain")
	registry:Register("ForestSlotCalculator", ForestSlotCalculator.new(), "Domain")
	registry:Register("GardenSlotCalculator", GardenSlotCalculator.new(), "Domain")
	registry:Register("ForgeStationSlotCalculator", ForgeStationSlotCalculator.new(), "Domain")
	registry:Register("BreweryStationSlotCalculator", BreweryStationSlotCalculator.new(), "Domain")

	-- Domain Policies
	registry:Register("HirePolicy", HirePolicy.new(), "Domain")
	registry:Register("AssignRolePolicy", AssignRolePolicy.new(), "Domain")
	registry:Register("AssignMinerOrePolicy", AssignMinerOrePolicy.new(), "Domain")
	registry:Register("AssignForgeRecipePolicy", AssignForgeRecipePolicy.new(), "Domain")
	registry:Register("AssignBreweryRecipePolicy", AssignBreweryRecipePolicy.new(), "Domain")
	registry:Register("MiningTickPolicy", MiningTickPolicy.new(), "Domain")
	registry:Register("ForgeTickPolicy", ForgeTickPolicy.new(), "Domain")
	registry:Register("BreweryTickPolicy", BreweryTickPolicy.new(), "Domain")
	registry:Register("ProductionEligibilityPolicy", ProductionEligibilityPolicy.new(), "Domain")
	-- New role policies (disabled until lot zones are implemented)
	registry:Register("AssignTailoringRecipePolicy", AssignTailoringRecipePolicy.new(), "Domain")
	registry:Register("AssignLumberjackTargetPolicy", AssignLumberjackTargetPolicy.new(), "Domain")
	registry:Register("AssignHerbalistTargetPolicy", AssignHerbalistTargetPolicy.new(), "Domain")
	registry:Register("AssignFarmerTargetPolicy", AssignFarmerTargetPolicy.new(), "Domain")
	registry:Register("TailorTickPolicy", TailorTickPolicy.new(), "Domain")
	registry:Register("HarvestTickPolicy", HarvestTickPolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("Components", ComponentRegistry.new(), "Infrastructure")
	registry:Register("WorkerEntityFactory", WorkerEntityFactory.new(), "Infrastructure")
	registry:Register("GameObjectFactory", GameObjectFactory.new(animationsFolder), "Infrastructure")
	registry:Register("WorkerRevealAdapter", WorkerRevealAdapter.new(), "Infrastructure")
	registry:Register("GameObjectSyncService", GameObjectSyncService.new(), "Infrastructure")
	registry:Register("WorkerPersistenceService", WorkerPersistenceService.new(), "Infrastructure")
	registry:Register("WorkerSyncService", WorkerSyncService.new(), "Infrastructure")
	registry:Register("MiningSlotService", MiningSlotService.new(), "Infrastructure")
	registry:Register("ForestSlotService", ForestSlotService.new(), "Infrastructure")
	registry:Register("GardenSlotService", GardenSlotService.new(), "Infrastructure")
	registry:Register("ForgeStationSlotService", ForgeStationSlotService.new(), "Infrastructure")
	registry:Register("BreweryStationSlotService", BreweryStationSlotService.new(), "Infrastructure")
	registry:Register("UndecidedSpawnService", UndecidedSpawnService.new(), "Infrastructure")

	-- Application Services
	registry:Register("HireWorker", HireWorker.new(), "Application")
	registry:Register("ProcessWorkerProduction", ProcessWorkerProduction.new(), "Application")
	registry:Register("ProcessMinerMining", ProcessMinerMining.new(), "Application")
	registry:Register("AssignWorkerRole", AssignWorkerRole.new(), "Application")
	registry:Register("AssignMinerOre", AssignMinerOre.new(), "Application")
	registry:Register("AssignForgeRecipe", AssignForgeRecipe.new(), "Application")
	registry:Register("AssignBreweryRecipe", AssignBreweryRecipe.new(), "Application")
	-- New role commands (disabled until lot zones are implemented)
	-- To enable: uncomment these registrations, wire client methods below, and add to tick loop
	registry:Register("AssignTailoringRecipe", AssignTailoringRecipe.new(), "Application")
	registry:Register("AssignLumberjackTarget", AssignLumberjackTarget.new(), "Application")
	registry:Register("AssignHerbalistTarget", AssignHerbalistTarget.new(), "Application")
	registry:Register("AssignFarmerTarget", AssignFarmerTarget.new(), "Application")
	registry:Register("ProcessHarvesting", ProcessHarvesting.new(), "Application")

	registry:InitAll()

	-- Cache refs needed by context handlers
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.MiningSlotCalculator = registry:Get("MiningSlotCalculator")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.MiningSlotService = registry:Get("MiningSlotService")
	self.ForestSlotService = registry:Get("ForestSlotService")
	self.GardenSlotService = registry:Get("GardenSlotService")
	self.ForgeStationSlotService = registry:Get("ForgeStationSlotService")
	self.BreweryStationSlotService = registry:Get("BreweryStationSlotService")
	self.UndecidedSpawnService = registry:Get("UndecidedSpawnService")
	self.GameObjectSyncService = registry:Get("GameObjectSyncService")
	self.WorkerLevelService = registry:Get("WorkerLevelService")
	self.HireWorker = registry:Get("HireWorker")
end

function WorkerContext:KnitStart()
	local registry = self.Registry

	-- Cross-context dependencies
	local LotContext = Knit.GetService("LotContext")
	local InventoryContext = Knit.GetService("InventoryContext")
	local UnlockContext = Knit.GetService("UnlockContext")
	local BuildingContext = Knit.GetService("BuildingContext")
	local UpgradeContext = Knit.GetService("UpgradeContext")
	registry:Register("LotContext", LotContext)
	registry:Register("InventoryContext", InventoryContext)
	registry:Register("UnlockContext", UnlockContext)
	registry:Register("BuildingContext", BuildingContext)
	registry:Register("UpgradeContext", UpgradeContext)
	self.LotContext = LotContext

	registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Cache refs for event handlers
	self.AssignMinerOrePolicy = registry:Get("AssignMinerOrePolicy")
	self.AssignForgeRecipePolicy = registry:Get("AssignForgeRecipePolicy")
	self.AssignBreweryRecipePolicy = registry:Get("AssignBreweryRecipePolicy")
	self.AssignLumberjackTargetPolicy = registry:Get("AssignLumberjackTargetPolicy")
	self.AssignHerbalistTargetPolicy = registry:Get("AssignHerbalistTargetPolicy")
	self.AssignFarmerTargetPolicy = registry:Get("AssignFarmerTargetPolicy")
	self.AssignWorkerRoleService = registry:Get("AssignWorkerRole")
	self.AssignMinerOreService = registry:Get("AssignMinerOre")
	self.AssignForgeRecipeService = registry:Get("AssignForgeRecipe")
	self.AssignBreweryRecipeService = registry:Get("AssignBreweryRecipe")
	self.ProcessWorkerProduction = registry:Get("ProcessWorkerProduction")
	self.ProcessMinerMining = registry:Get("ProcessMinerMining")

	self.AssignTailoringRecipeService = registry:Get("AssignTailoringRecipe")
	self.AssignHerbalistTargetService = registry:Get("AssignHerbalistTarget")
	-- TODO: Enable when lot zones (Farm) are implemented
	-- self.AssignFarmerTargetService = registry:Get("AssignFarmerTarget")
	self.AssignLumberjackTargetService = registry:Get("AssignLumberjackTarget")
	self.ProcessHarvesting = registry:Get("ProcessHarvesting")

	-- Subscribe to lifecycle events
	GameEvents.Bus:On(Events.Building.RestoreCompleted, function(userId)
		self:_SpawnWorkersFromPendingData(userId)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadWorkersOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "WorkerContext") -- data staged; entities created after building restore event
			end)
			:catch(function(err)
				warn("[WorkerContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self:_CleanupPlayerWorkers(player)
	end)

	-- Register ECS systems with the Planck scheduler
	ServerScheduler:RegisterSystem(function()
		self.GameObjectSyncService:SyncDirtyEntities()
	end, "WorkerSync")

	ServerScheduler:RegisterSystem(function()
		self.ProcessWorkerProduction:Execute()
		self.ProcessMinerMining:Execute()
		self.ProcessHarvesting:Execute()
	end, "WorkerProduction")

end

---
--- Player Data Loading
---

--- @within WorkerContext
--- @private
function WorkerContext:_LoadWorkersOnPlayerJoin(player: Player)
	local userId = player.UserId
	local workersData = self.PersistenceService:LoadWorkerData(player):unwrapOr(nil)

	if workersData and next(workersData) ~= nil then
		self._PendingWorkerData[userId] = workersData
	end
	-- Entities are not created here. _SpawnWorkersFromPendingData runs on Building.RestoreCompleted.
	-- Hydration (empty atom) is deferred to the same point so the client receives
	-- the full worker state in one shot after the lot exists.
end

--- @within WorkerContext
--- @private
function WorkerContext:_RestoreWorker(userId: number, workerId: string, workerData: any)
	local isUndecided = workerData.AssignedTo == nil or workerData.AssignedTo == "Undecided"
	local spawnPosition = if isUndecided then self.UndecidedSpawnService:GetSpawnPosition(userId) else Vector3.new(0, 0, 0)
	local entity = self.EntityFactory:CreateWorker(userId, workerId, workerData.Rank, spawnPosition)

	self:_RestoreLevel(entity, workerData)
	self:_RestoreAssignment(entity, workerData)
	self:_RestoreEquipment(entity, workerData)
	self:_RestoreRank(entity, workerData)
end

--- @within WorkerContext
--- @private
function WorkerContext:_RestoreLevel(entity: any, workerData: any)
	if workerData.Level <= 1 and workerData.Experience <= 0 then return end
	self.EntityFactory:LevelUpWorker(entity, workerData.Level, workerData.Experience)
end

--- @within WorkerContext
--- @private
function WorkerContext:_RestoreAssignment(entity: any, workerData: any)
	if not (workerData.AssignedTo or workerData.TaskTarget or workerData.LastProductionTick) then return end

	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	if not assignment then return end

	local updated = table.clone(assignment)
	updated.Role = workerData.AssignedTo or "Undecided"
	updated.TaskTarget = workerData.TaskTarget or nil
	updated.LastProductionTick = workerData.LastProductionTick or os.time()
	updated.SlotIndex = workerData.SlotIndex or nil
	self.World:set(entity, self.Components.AssignmentComponent, updated)
end

--- @within WorkerContext
--- @private
function WorkerContext:_HydrateRoleAssignment(userId: number, workerId: string, roleId: string, targetId: string)
	return Catch(function()
		local roleConfig = HYDRATION_ROLE_CONFIG[roleId]
		if not roleConfig then return end

		local policy = self[roleConfig.PolicyField]
		if not policy then return end

		local result = policy:Check(userId, workerId, targetId)
		if not result.success then return end

		local entity = result.value.Entity

		if roleConfig.SlotServiceField and roleConfig.ResultInstanceKey then
			local slotService = self[roleConfig.SlotServiceField]
			local targetInstance = result.value[roleConfig.ResultInstanceKey]
			if slotService and targetInstance then
				if roleConfig.RequireModelForSlot and not targetInstance:IsA("Model") then
					return
				end

				local targetCFrame = targetInstance:GetPivot()
				local slotTargetId = result.value.SlotTargetId or targetId
				local slotIndex, standPos, lookAtPos =
					slotService:ClaimSlot(userId, workerId, slotTargetId, targetCFrame, targetInstance)
				self.EntityFactory:AssignSlotIndex(entity, slotIndex)
				self.EntityFactory:UpdatePosition(entity, standPos.X, standPos.Y, standPos.Z, lookAtPos.X, lookAtPos.Y, lookAtPos.Z)
			end
		end

		local targetConfig = roleConfig.DurationConfig[targetId]
		local duration = targetConfig and targetConfig[roleConfig.DurationField]
		if not duration then return end
		self.EntityFactory:StartMining(entity, targetId, duration, roleConfig.AnimationState)
	end, "Worker:HydrateRoleAssignment")
end

--- @within WorkerContext
--- @private
function WorkerContext:_RestoreEquipment(entity: any, workerData: any)
	if not workerData.Equipment or not workerData.Equipment.ToolId then return end
	self.EntityFactory:SetEquipment(entity, workerData.Equipment.ToolId, workerData.Equipment.Slot or "MainHand")
end


--- @within WorkerContext
--- @private
function WorkerContext:_RestoreRank(entity: any, workerData: any)
	local correctRank = self.WorkerLevelService:GetRankForLevel(workerData.Level or 1)
	if correctRank ~= "Apprentice" then
		self.EntityFactory:SetRank(entity, correctRank)
	end
end

--- @within WorkerContext
--- @private
function WorkerContext:_CorrectWorkerRanks(userId: number, workersData: any)
	for workerId, workerData in workersData do
		local correctRank = self.WorkerLevelService:GetRankForLevel(workerData.Level or 1)
		if correctRank ~= (workerData.Rank or "Apprentice") then
			self.SyncService:UpdateWorkerRank(userId, workerId, correctRank)
		end
	end
end

--- @within WorkerContext
--- @private
function WorkerContext:_SpawnWorkersFromPendingData(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	local workersData = self._PendingWorkerData[userId]
	self._PendingWorkerData[userId] = nil

	if workersData then
		self:_RestoreAllWorkers(userId, workersData)
		self.GameObjectSyncService:SyncDirtyEntities()
		self:_HydrateAllAssignments(userId, workersData)
		self.SyncService:LoadUserWorkers(userId, workersData)
		self:_CorrectWorkerRanks(userId, workersData)
	end

	if player then
		self.SyncService:HydratePlayer(player)
	end
end

--- @within WorkerContext
--- @private
function WorkerContext:_RestoreAllWorkers(userId: number, workersData: any)
	for workerId, workerData in workersData do
		self:_RestoreWorker(userId, workerId, workerData)
	end
end

--- @within WorkerContext
--- @private
function WorkerContext:_HydrateAllAssignments(userId: number, workersData: any)
	return Catch(function()
		for workerId, workerData in workersData do
			if workerData.AssignedTo and workerData.TaskTarget then
				self:_HydrateRoleAssignment(userId, workerId, workerData.AssignedTo, workerData.TaskTarget)
			end
		end
	end, "Worker:HydrateAllAssignments")
end

--- @within WorkerContext
--- @private
function WorkerContext:_CleanupPlayerWorkers(player: Player)
	local userId = player.UserId
	self._PendingWorkerData[userId] = nil

	-- Query all worker entities for this player
	local workerEntities = self.EntityFactory:QueryUserWorkers(userId)

	-- Save all workers before cleanup
	for _, workerData in workerEntities do
		self.PersistenceService:SaveWorkerEntity(player, workerData.Entity)
	end

	-- Delete GameObjects and entities
	for _, workerData in workerEntities do
		self.GameObjectSyncService:DeleteEntity(workerData.Entity)
		self.EntityFactory:DeleteWorker(workerData.Entity)
	end

	-- Release all slot tracking for this user
	self.MiningSlotService:ReleaseAllSlotsForUser(userId)
	self.ForestSlotService:ReleaseAllSlotsForUser(userId)
	self.GardenSlotService:ReleaseAllSlotsForUser(userId)
	self.ForgeStationSlotService:ReleaseAllSlotsForUser(userId)

	-- Remove from Charm atom (client sync)
	self.SyncService:RemoveUserWorkers(userId)

end

---
--- Server-to-Server API Methods (for cross-context calls)
---

--[=[
	Hires a new worker of the given type for the player.
	@within WorkerContext
	@param userId number
	@param workerType string
	@return Result.Result<any>
]=]
function WorkerContext:HireWorkerForUser(userId: number, workerType: string): Result.Result<any>
	return Catch(function()
		return self.HireWorker:Execute(userId, workerType)
	end, "Worker:HireWorkerForUser")
end

--[=[
	Returns a read-only snapshot of all workers for the given player.
	@within WorkerContext
	@param userId number
	@return Result.Result<{ [string]: TWorker }>
]=]
function WorkerContext:GetWorkersForUser(userId: number): Result.Result<{ [string]: TWorker }>
	return Catch(function()
		local workers = self.SyncService:GetWorkersReadOnly(userId)
		return workers
	end, "Worker:GetWorkersForUser")
end

--[=[
	Returns the production speed multiplier for a specific worker based on level and type.
	@within WorkerContext
	@param userId number
	@param workerId string
	@return Result.Result<number>
]=]
function WorkerContext:GetWorkerProductionSpeed(userId: number, workerId: string): Result.Result<number>
	return Catch(function()
		local worker = self.SyncService:GetWorkerReadOnly(userId, workerId)
		if not worker then
			return Err("WorkerNotFound", "Worker not found", { userId = userId, workerId = workerId })
		end
		local speedMultiplier = self.WorkerLevelService:CalculateProductionSpeed(worker.Level, worker.Rank)
		return speedMultiplier
	end, "Worker:GetWorkerProductionSpeed")
end

--[=[
	Assigns the worker to the given role.
	@within WorkerContext
	@param userId number
	@param workerId string
	@param roleId string
	@return Result.Result<any>
]=]
function WorkerContext:AssignWorkerRole(userId: number, workerId: string, roleId: string): Result.Result<any>
	return Catch(function()
		return self.AssignWorkerRoleService:Execute(userId, workerId, roleId)
	end, "Worker:AssignWorkerRole")
end

--[=[
	Assigns a Miner worker to a specific ore type in their lot's Mine zone.
	@within WorkerContext
	@param userId number
	@param workerId string
	@param oreId string
	@return Result.Result<any>
]=]
function WorkerContext:AssignMinerOreForUser(userId: number, workerId: string, oreId: string): Result.Result<any>
	return Catch(function()
		return self.AssignMinerOreService:Execute(userId, workerId, oreId)
	end, "Worker:AssignMinerOreForUser")
end

--[=[
	Assigns a Forge worker to automate a specific recipe.
	@within WorkerContext
	@param userId number
	@param workerId string
	@param recipeId string
	@return Result.Result<any>
]=]
function WorkerContext:AssignForgeRecipeForUser(userId: number, workerId: string, recipeId: string): Result.Result<any>
	return Catch(function()
		return self.AssignForgeRecipeService:Execute(userId, workerId, recipeId)
	end, "Worker:AssignForgeRecipeForUser")
end

--[=[
	Assigns a Herbalist worker to a specific plant type in their lot's Garden zone.
	@within WorkerContext
	@param userId number
	@param workerId string
	@param plantId string
	@return Result.Result<any>
]=]
function WorkerContext:AssignHerbalistTargetForUser(userId: number, workerId: string, plantId: string): Result.Result<any>
	return Catch(function()
		return self.AssignHerbalistTargetService:Execute(userId, workerId, plantId)
	end, "Worker:AssignHerbalistTargetForUser")
end

--[=[
	Assigns a Brewery worker to automate a specific recipe.
	@within WorkerContext
	@param userId number
	@param workerId string
	@param recipeId string
	@return Result.Result<any>
]=]
function WorkerContext:AssignBreweryRecipeForUser(userId: number, workerId: string, recipeId: string): Result.Result<any>
	return Catch(function()
		return self.AssignBreweryRecipeService:Execute(userId, workerId, recipeId)
	end, "Worker:AssignBreweryRecipeForUser")
end

---
--- Client API Methods
---

--- Request worker state (triggers hydration)
function WorkerContext.Client:RequestWorkerState(player: Player): boolean
	self.Server.SyncService:HydratePlayer(player)
	return true
end

--- Hire a worker
function WorkerContext.Client:HireWorker(player: Player, workerType: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.HireWorker:Execute(userId, workerType)
	end, "Worker.Client:HireWorker")
end

--- Assign worker to role
function WorkerContext.Client:AssignRole(player: Player, workerId: string, roleId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignWorkerRoleService:Execute(userId, workerId, roleId)
	end, "Worker.Client:AssignRole")
end

--- Assign miner worker to an ore type
function WorkerContext.Client:AssignMinerOre(player: Player, workerId: string, oreId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignMinerOreService:Execute(userId, workerId, oreId)
	end, "Worker.Client:AssignMinerOre")
end

--- Assign Forge worker to craft a specific recipe automatically
function WorkerContext.Client:AssignForgeRecipe(player: Player, workerId: string, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignForgeRecipeService:Execute(userId, workerId, recipeId)
	end, "Worker.Client:AssignForgeRecipe")
end

--- Assign Brewery worker to brew a specific recipe automatically
function WorkerContext.Client:AssignBreweryRecipe(player: Player, workerId: string, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignBreweryRecipeService:Execute(userId, workerId, recipeId)
	end, "Worker.Client:AssignBreweryRecipe")
end

-- TODO: Enable when lot zones (Forest/Garden/Farm) are implemented
-- Uncomment each block, then add the corresponding Blink remote in the network schema.

function WorkerContext.Client:AssignTailoringRecipe(player: Player, workerId: string, recipeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignTailoringRecipeService:Execute(userId, workerId, recipeId)
	end, "Worker.Client:AssignTailoringRecipe")
end

function WorkerContext.Client:AssignLumberjackTarget(player: Player, workerId: string, treeId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignLumberjackTargetService:Execute(userId, workerId, treeId)
	end, "Worker.Client:AssignLumberjackTarget")
end

function WorkerContext.Client:AssignHerbalistTarget(player: Player, workerId: string, plantId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AssignHerbalistTargetService:Execute(userId, workerId, plantId)
	end, "Worker.Client:AssignHerbalistTarget")
end

-- function WorkerContext.Client:AssignFarmerTarget(player: Player, workerId: string, cropId: string)
-- 	local userId = player.UserId
-- 	return Catch(function()
-- 		return self.Server.AssignFarmerTargetService:Execute(userId, workerId, cropId)
-- 	end, "Worker.Client:AssignFarmerTarget")
-- end

WrapContext(WorkerContext, "WorkerContext")

return WorkerContext
