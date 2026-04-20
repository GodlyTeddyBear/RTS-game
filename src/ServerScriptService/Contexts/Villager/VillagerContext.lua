--!strict

--[=[
    @class VillagerContext
    Manages villager spawning, behavior processing, and lifecycle across the game world.
    @server
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local VillagerConfig = require(ReplicatedStorage.Contexts.Villager.Config.VillagerConfig)
local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local VillagerECSWorldService = require(script.Parent.Infrastructure.ECS.VillagerECSWorldService)
local VillagerComponentRegistry = require(script.Parent.Infrastructure.ECS.VillagerComponentRegistry)
local VillagerEntityFactory = require(script.Parent.Infrastructure.ECS.VillagerEntityFactory)
local VillagerModelFactory = require(script.Parent.Infrastructure.Services.VillagerModelFactory)
local VillagerRouteDiscoveryService = require(script.Parent.Infrastructure.Services.VillagerRouteDiscoveryService)
local VillagerPathingService = require(script.Parent.Infrastructure.Services.VillagerPathingService)
local VillagerGameObjectSyncService = require(script.Parent.Infrastructure.Persistence.VillagerGameObjectSyncService)
local SelectCustomerTargetPolicy = require(script.Parent.VillagerDomain.Policies.SelectCustomerTargetPolicy)
local SpawnVillager = require(script.Parent.Application.Commands.SpawnVillager)
local ProcessVillagerBehavior = require(script.Parent.Application.Commands.ProcessVillagerBehavior)

local Catch, Ok = Result.Catch, Result.Ok
local Events = GameEvents.Events

local VillagerContext = Knit.CreateService({
	Name = "VillagerContext",
	Client = {},
})

function VillagerContext:KnitInit()
	local registry = Registry.new("Server")
	local ecsWorldService = VillagerECSWorldService.new()
	local world = ecsWorldService:GetWorld()
	local modelsFolder = self:_ResolveVillagerModelsFolder()
	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Animations")

	registry:Register("VillagerECSWorldService", ecsWorldService, "Infrastructure")
	registry:Register("World", world)
	registry:Register("Components", VillagerComponentRegistry.new(), "Infrastructure")
	registry:Register("VillagerEntityFactory", VillagerEntityFactory.new(), "Infrastructure")
	registry:Register("VillagerModelFactory", VillagerModelFactory.new(modelsFolder, animationsFolder), "Infrastructure")
	registry:Register("VillagerRouteDiscoveryService", VillagerRouteDiscoveryService.new(), "Infrastructure")
	registry:Register("VillagerPathingService", VillagerPathingService.new(), "Infrastructure")
	registry:Register("VillagerGameObjectSyncService", VillagerGameObjectSyncService.new(), "Infrastructure")
	registry:Register("SelectCustomerTargetPolicy", SelectCustomerTargetPolicy.new(), "Domain")
	registry:Register("SpawnVillager", SpawnVillager.new(), "Application")
	registry:Register("ProcessVillagerBehavior", ProcessVillagerBehavior.new(), "Application")

	registry:InitAll()

	self.Registry = registry
	self.World = world
	self.Components = registry:Get("Components")
	self.EntityFactory = registry:Get("VillagerEntityFactory")
	self.GameObjectSyncService = registry:Get("VillagerGameObjectSyncService")
	self.SpawnVillagerService = registry:Get("SpawnVillager")
	self.ProcessVillagerBehaviorService = registry:Get("ProcessVillagerBehavior")
	self._lastCustomerSpawnAt = 0
end

function VillagerContext:KnitStart()
	self.Registry:StartAll()

	ServerScheduler:RegisterSystem(function()
		self.GameObjectSyncService:PollPositions()
	end, "VillagerPositionPoll")

	ServerScheduler:RegisterSystem(function()
		self.ProcessVillagerBehaviorService:Execute()
	end, "VillagerBehavior")

	ServerScheduler:RegisterSystem(function()
		self.GameObjectSyncService:SyncDirtyEntities()
	end, "VillagerSync")

	GameEvents.Bus:On(Events.Lot.LotSpawned, function(_userId: number)
		self:_SpawnCustomerIfCapacity()
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_CleanupVillagersForUser(player.UserId)
	end)

	self:_StartSpawnLoop()
end

--[=[
	Spawns a villager entity in the world.
	@within VillagerContext
	@param archetypeId string? -- Optional villager archetype ID; if nil, selects weighted random archetype
	@return Result<{ Entity: any, VillagerId: string }> -- Result containing spawned entity and unique ID
]=]
function VillagerContext:SpawnVillager(archetypeId: string?): Result.Result<{ Entity: any, VillagerId: string }>
	return Catch(function()
		return self.SpawnVillagerService:Execute(archetypeId)
	end, "Villager:SpawnVillager")
end

--[=[
	Spawns a customer villager.
	@within VillagerContext
	@return Result<{ Entity: any, VillagerId: string }> -- Result containing spawned customer entity
]=]
function VillagerContext:SpawnCustomer(): Result.Result<{ Entity: any, VillagerId: string }>
	return self:SpawnVillager("Customer")
end

--[=[
	Spawns a merchant villager.
	@within VillagerContext
	@return Result<{ Entity: any, VillagerId: string }> -- Result containing spawned merchant entity
]=]
function VillagerContext:SpawnMerchant(): Result.Result<{ Entity: any, VillagerId: string }>
	return self:SpawnVillager("Merchant")
end

--[=[
	Gets the ECS world managing all villager entities.
	@within VillagerContext
	@return Result<any> -- Result containing the JECS world
]=]
function VillagerContext:GetWorld(): Result.Result<any>
	return Ok(self.World)
end

--[=[
	Gets the factory for creating and querying villager entities.
	@within VillagerContext
	@return Result<any> -- Result containing the entity factory
]=]
function VillagerContext:GetEntityFactory(): Result.Result<any>
	return Ok(self.EntityFactory)
end

-- Starts background loop that spawns customers at configured intervals.
function VillagerContext:_StartSpawnLoop()
	task.spawn(function()
		while true do
			task.wait(VillagerConfig.SPAWN_INTERVAL_SECONDS)
			self:_SpawnCustomerIfCapacity()
		end
	end)
end

-- Spawns a customer if spawn interval has elapsed and customer count is below max.
function VillagerContext:_SpawnCustomerIfCapacity()
	local now = os.clock()
	-- Throttle spawn attempts to prevent rapid successive spawns
	if now - self._lastCustomerSpawnAt < VillagerConfig.SPAWN_INTERVAL_SECONDS then
		return
	end

	-- Stop spawning if customer cap is reached
	if #self.EntityFactory:QueryCustomers() >= VillagerConfig.MAX_CUSTOMERS then
		return
	end

	self._lastCustomerSpawnAt = now
	self:SpawnCustomer()
end

-- Cleans up all villagers currently visiting a player lot when player leaves.
function VillagerContext:_CleanupVillagersForUser(userId: number)
	for _, entity in ipairs(self.EntityFactory:QueryCustomers()) do
		local visit = self.EntityFactory:GetVisit(entity)
		if visit and visit.TargetUserId == userId then
			self.EntityFactory:RequestCleanup(entity, "PlayerRemoving")
		end
	end
end

-- Resolves the Villagers folder containing model templates; returns nil if not found.
function VillagerContext:_ResolveVillagerModelsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local entities = assets and assets:FindFirstChild("Entities")
	local villagers = entities and entities:FindFirstChild("Villagers")
	if villagers and villagers:IsA("Folder") then
		return villagers
	end
	return nil
end

--[=[
	Client-side RPC to spawn a customer villager.
	@within VillagerContext
	@param player Player -- The player making the request
	@return Result<{ Entity: any, VillagerId: string }> -- Result containing spawned customer or error
]=]
function VillagerContext.Client:SpawnCustomer(player: Player)
	if player.UserId <= 0 then
		return nil
	end
	return self.Server:SpawnCustomer()
end

WrapContext(VillagerContext, "VillagerContext")

return VillagerContext
