--!strict

--[=[
	@class NPCContext
	Knit service managing all NPC entities, models, and related combat systems.
	Exposes spawn/cleanup commands and provides access to the combat ECS world and factories.
	@server
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

-- ECS Infrastructure
local CombatECSWorldService = require(script.Parent.Infrastructure.ECS.CombatECSWorldService)
local CombatComponentRegistry = require(script.Parent.Infrastructure.ECS.CombatComponentRegistry)
local NPCEntityFactory = require(script.Parent.Infrastructure.ECS.NPCEntityFactory)

-- Persistence Infrastructure
local NPCGameObjectSyncService = require(script.Parent.Infrastructure.Persistence.NPCGameObjectSyncService)

-- Infrastructure Services
local NPCModelFactory = require(script.Parent.Infrastructure.Services.NPCModelFactory)
local NPCEquipmentService = require(script.Parent.Infrastructure.Services.NPCEquipmentService)
local NPCRevealAdapter = require(script.Parent.Infrastructure.Reveal.NPCRevealAdapter)

type TNPCEntityFactory = NPCEntityFactory.TNPCEntityFactory
type TNPCModelFactory = NPCModelFactory.TNPCModelFactory
type TNPCGameObjectSyncService = NPCGameObjectSyncService.TNPCGameObjectSyncService
type TCombatComponentRegistry = CombatComponentRegistry.TCombatComponentRegistry

-- Domain Policies
local AdventurerSpawnPolicy = require(script.Parent.NPCDomain.Policies.AdventurerSpawnPolicy)
local EnemyWaveSpawnPolicy = require(script.Parent.NPCDomain.Policies.EnemyWaveSpawnPolicy)

-- Application Services
local SpawnAdventurerParty = require(script.Parent.Application.Commands.SpawnAdventurerParty)
local SpawnEnemyWave = require(script.Parent.Application.Commands.SpawnEnemyWave)
local DestroyAllNPCs = require(script.Parent.Application.Commands.DestroyAllNPCs)

-- Asset loading
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)

local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch = Result.Catch
local Ok = Result.Ok

local NPCContext = Knit.CreateService({
	Name = "NPCContext",
	Client = {},
})

---
-- Knit Lifecycle
---

--[=[
	Knit lifecycle: register and initialize all infrastructure services.
	@within NPCContext
	@private
]=]
function NPCContext:KnitInit()
	local registry = Registry.new("Server")
	self:_RegisterInfrastructure(registry)
	registry:InitAll()
	self:_CacheServiceRefs(registry)
	self.Registry = registry
end

-- Register all ECS, persistence, and application services in the registry.
function NPCContext:_RegisterInfrastructure(registry: any)
	-- Create combat ECS world and load entity assets
	local ecsWorldService = CombatECSWorldService.new()
	local world = ecsWorldService:GetWorld()

	local entitiesFolder = ReplicatedStorage.Assets.Entities
	local entityRegistry = AssetFetcher.CreateEntityRegistry(entitiesFolder)
	local toolsFolder = ReplicatedStorage.Assets.Items.Tools
	local armorFolder = ReplicatedStorage.Assets.Items.Armor
	local accessoriesFolder = ReplicatedStorage.Assets.Items.Accessories
	local toolRegistry = AssetFetcher.CreateToolRegistry(toolsFolder)
	local armorRegistry = AssetFetcher.CreateArmorRegistry(armorFolder)
	local accessoryRegistry = AssetFetcher.CreateAccessoryRegistry(accessoriesFolder)
	local npcEquipmentService = NPCEquipmentService.new(toolRegistry, armorRegistry, accessoryRegistry)

	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Animations")

	-- Register infrastructure: ECS world, components, factories
	registry:Register("CombatECSWorldService", ecsWorldService, "Infrastructure")
	registry:Register("World", world)
	registry:Register("EntityRegistry", entityRegistry)
	registry:Register("NPCEquipmentService", npcEquipmentService)
	registry:Register("Components", CombatComponentRegistry.new(), "Infrastructure")
	registry:Register("AdventurerSpawnPolicy", AdventurerSpawnPolicy.new(), "Domain")
	registry:Register("EnemyWaveSpawnPolicy", EnemyWaveSpawnPolicy.new(), "Domain")
	registry:Register("NPCEntityFactory", NPCEntityFactory.new(), "Infrastructure")
	registry:Register("NPCModelFactory", NPCModelFactory.new(animationsFolder), "Infrastructure")
	registry:Register("NPCRevealAdapter", NPCRevealAdapter.new(), "Infrastructure")
	registry:Register("NPCGameObjectSyncService", NPCGameObjectSyncService.new(), "Infrastructure")

	-- Register application commands: spawn/cleanup operations
	registry:Register("SpawnAdventurerParty", SpawnAdventurerParty.new(), "Application")
	registry:Register("SpawnEnemyWave", SpawnEnemyWave.new(), "Application")
	registry:Register("DestroyAllNPCs", DestroyAllNPCs.new(), "Application")
end

-- Cache service references from registry for easy access.
function NPCContext:_CacheServiceRefs(registry: any)
	-- Infrastructure references for ECS world and entity/model management
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.NPCModelFactory = registry:Get("NPCModelFactory")
	self.NPCGameObjectSyncService = registry:Get("NPCGameObjectSyncService")

	-- Application service references for spawn/cleanup commands
	self.SpawnAdventurerPartyService = registry:Get("SpawnAdventurerParty")
	self.SpawnEnemyWaveService = registry:Get("SpawnEnemyWave")
	self.DestroyAllNPCsService = registry:Get("DestroyAllNPCs")
end

--[=[
	Knit lifecycle: register sync systems with scheduler and cleanup on player leave.
	@within NPCContext
	@private
]=]
function NPCContext:KnitStart()
	-- Register ECS sync systems with the Planck scheduler (runs every Heartbeat)
	ServerScheduler:RegisterSystem(function()
		self.NPCGameObjectSyncService:PollPositions()
	end, "NPCPositionPoll")

	ServerScheduler:RegisterSystem(function()
		self.NPCGameObjectSyncService:SyncDirtyEntities()
	end, "NPCSync")

	-- Cleanup on player leave: destroy all NPCs for the departing player
	Players.PlayerRemoving:Connect(function(player)
		self:DestroyAllNPCsForUser(player.UserId)
	end)

	print("NPCContext started")
end

---
-- Server-to-Server API
---

--[=[
	Spawn an adventurer party as NPC entities and models in the dungeon.
	@within NPCContext
	@param userId number -- Player ID
	@param adventurers { [string]: any } -- Adventurer data from Guild context
	@param spawnPoints { any } -- Spawn locations from Dungeon Start area
	@return Result.Result<{ [string]: any }> -- Map of adventurerId -> entity, or error
]=]
function NPCContext:SpawnAdventurerPartyForUser(
	userId: number,
	adventurers: { [string]: any },
	spawnPoints: { any }
): Result.Result<{ [string]: any }>
	return Catch(function()
		return self.SpawnAdventurerPartyService:Execute(userId, adventurers, spawnPoints)
	end, "NPC:SpawnAdventurerPartyForUser")
end

--[=[
	Spawn a wave of enemies for a dungeon zone.
	@within NPCContext
	@param userId number -- Player ID
	@param waveNumber number -- Wave index
	@param zoneId string -- Zone ID for wave config lookup
	@param spawnPoints { any } -- Spawn locations
	@return Result.Result<{ any }> -- Array of enemy entities, or error
]=]
function NPCContext:SpawnEnemyWaveForUser(
	userId: number,
	waveNumber: number,
	zoneId: string,
	spawnPoints: { any }
): Result.Result<{ any }>
	return Catch(function()
		return self.SpawnEnemyWaveService:Execute(userId, waveNumber, zoneId, spawnPoints)
	end, "NPC:SpawnEnemyWaveForUser")
end

--[=[
	Destroy all NPC entities and models for a player.
	@within NPCContext
	@param userId number -- Player ID
	@return Result.Result<boolean> -- Ok(true) on success, error if invalid userId
]=]
function NPCContext:DestroyAllNPCsForUser(userId: number): Result.Result<boolean>
	return Catch(function()
		return self.DestroyAllNPCsService:Execute(userId)
	end, "NPC:DestroyAllNPCsForUser")
end

--[=[
	Expose the combat JECS world to other contexts.
	@within NPCContext
	@return Result.Result<any> -- The combat JECS world instance
]=]
function NPCContext:GetWorld(): Result.Result<any>
	return Ok(self.World)
end

--[=[
	Expose the combat component registry to other contexts.
	@within NPCContext
	@return Result.Result<TCombatComponentRegistry> -- The component registry instance
]=]
function NPCContext:GetComponents(): Result.Result<TCombatComponentRegistry>
	return Ok(self.Components)
end

--[=[
	Expose the NPC entity factory to other contexts.
	@within NPCContext
	@return Result.Result<TNPCEntityFactory> -- The entity factory instance
]=]
function NPCContext:GetEntityFactory(): Result.Result<TNPCEntityFactory>
	return Ok(self.NPCEntityFactory)
end

--[=[
	Expose the NPC model factory to other contexts.
	@within NPCContext
	@return Result.Result<TNPCModelFactory> -- The model factory instance
]=]
function NPCContext:GetModelFactory(): Result.Result<TNPCModelFactory>
	return Ok(self.NPCModelFactory)
end

--[=[
	Expose the GameObject sync service to other contexts.
	@within NPCContext
	@return Result.Result<TNPCGameObjectSyncService> -- The sync service instance
]=]
function NPCContext:GetGameObjectSyncService(): Result.Result<TNPCGameObjectSyncService>
	return Ok(self.NPCGameObjectSyncService)
end

WrapContext(NPCContext, "NPCContext")

return NPCContext
