--!strict

--[[
	Lot Context - Main Knit service managing lot lifecycle

	DDD Architecture:
	- Domain Layer: Policies and specs (SpawnPolicy, CleanupPolicy)
	- Application Layer: Orchestration (SpawnLotService, CleanupLotService)
	- Infrastructure Layer: Technical implementation (ECSWorldService, GameObjectSyncService)

	Context Layer Responsibility:
	- Initialize all layers with constructor injection
	- Knit lifecycle management
	- Pure bridges to Application services (no business logic)
	- Cross-context integration with WorldContext for lot area claims
]]

--[=[
	@class LotContext
	Main Knit service managing lot lifecycle: spawning, cleanup, teleportation, and zone access.
	Coordinates domain policies, application orchestration, and infrastructure ECS systems.
	@server
]=]
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Result = require(ReplicatedStorage.Utilities.Result)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch, Try = Result.Catch, Result.Try
local Ok = Result.Ok
local Err = Result.Err
local MentionSuccess = Result.MentionSuccess

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)

-- ECS Infrastructure
local ECSWorldService = require(script.Parent.Infrastructure.ECS.ECSWorldService)
local ComponentRegistry = require(script.Parent.Infrastructure.ECS.ComponentRegistry)
local LotEntityFactory = require(script.Parent.Infrastructure.ECS.LotEntityFactory)

-- Persistence Infrastructure
local GameObjectSyncService = require(script.Parent.Infrastructure.Persistence.GameObjectSyncService)

-- Infrastructure Services
local GameObjectFactory = require(script.Parent.Infrastructure.Services.GameObjectFactory)

-- Domain policies
local SpawnPolicy = require(script.Parent.LotDomain.Policies.SpawnPolicy)
local CleanupPolicy = require(script.Parent.LotDomain.Policies.CleanupPolicy)

-- Application services
local SpawnLotService = require(script.Parent.Application.Commands.SpawnLotService)
local CleanupLotService = require(script.Parent.Application.Commands.CleanupLotService)

local LotContext = Knit.CreateService({
	Name = "LotContext",
	Client = {},
})

local TELEPORT_COOLDOWN_SECONDS = 1
local ON_JOIN_TEAM_NAME = "OnJoin"
local ON_PLAY_TEAM_NAME = "OnPlay"

--[=[
	Initialize all context layers with the Registry pattern.
	Runs during Knit initialization. Sets up ECS world, services, and lifecycle infrastructure.
	@within LotContext
]=]
function LotContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Create ECS world first (foundational — other services depend on the world value)
	local ecsWorldService = ECSWorldService.new()
	local world = ecsWorldService:GetWorld()

	-- Create or get Workspace Lots folder
	local lotsFolder = Instance.new("Folder")
	lotsFolder.Name = "Lots"
	lotsFolder.Parent = workspace

	-- Create asset registry
	local lotsAssetsFolder = game:GetService("ReplicatedStorage").Assets:FindFirstChild("Lots")
	if not lotsAssetsFolder then
		warn("[LotContext] Assets/Lots folder not found, creating empty placeholder")
		lotsAssetsFolder = Instance.new("Folder")
		lotsAssetsFolder.Name = "Lots"
		lotsAssetsFolder.Parent = game:GetService("ReplicatedStorage").Assets
	end
	local lotRegistry = AssetFetcher.CreateLotRegistry(lotsAssetsFolder)

	-- Shared state for tracking and ID generation
	local playersWithLots = {} :: { [Player]: string }
	local lotIdCounter = { Value = 0 }

	-- Register raw values (no Init needed)
	registry:Register("ECSWorldService", ecsWorldService, "Infrastructure")
	registry:Register("World", world)
	registry:Register("LotRegistry", lotRegistry)
	registry:Register("PlayersWithLots", playersWithLots)
	registry:Register("LotIdCounter", lotIdCounter)

	-- Register services (zero-arg .new(); Init pulls deps from registry)
	registry:Register("Components", ComponentRegistry.new(), "Infrastructure")
	registry:Register("LotEntityFactory", LotEntityFactory.new(), "Infrastructure")
	registry:Register("GameObjectFactory", GameObjectFactory.new(lotsFolder), "Infrastructure")
	registry:Register("GameObjectSyncService", GameObjectSyncService.new(), "Infrastructure")
	registry:Register("SpawnPolicy", SpawnPolicy.new(), "Domain")
	registry:Register("CleanupPolicy", CleanupPolicy.new(), "Domain")
	registry:Register("SpawnLotService", SpawnLotService.new(), "Application")
	registry:Register("CleanupLotService", CleanupLotService.new(), "Application")

	registry:InitAll()

	-- Cache refs
	self.World = world
	self.Components = registry:Get("Components")
	self.EntityFactory = registry:Get("LotEntityFactory")
	self.GameObjectFactory = registry:Get("GameObjectFactory")
	self.GameObjectSyncService = registry:Get("GameObjectSyncService")
	self.SpawnLotService = registry:Get("SpawnLotService")
	self.CleanupLotService = registry:Get("CleanupLotService")
	self.PlayersWithLots = playersWithLots
	self.LotIdCounter = lotIdCounter
	self.PlayerToLotModel = {} :: { [Player]: Model }
	self.LotTeleportConnections = {} :: { [Player]: RBXScriptConnection }
	self.LotTeleportDebounce = {} :: { [number]: number }
end

--[=[
	Hook up lifecycle events and cross-context dependencies.
	Runs after all services have called KnitInit. Sets up player lifecycle handlers.
	@within LotContext
]=]
function LotContext:KnitStart()
	-- Cross-context dependencies available after all KnitInit calls
	self.WorldContext = Knit.GetService("WorldContext")
	self.RemoteLotContext = Knit.GetService("RemoteLotContext")

	for _, player in Players:GetPlayers() do
		self:_AssignPlayerToTeamByName(player, ON_JOIN_TEAM_NAME)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_AssignPlayerToTeamByName(player, ON_JOIN_TEAM_NAME)
	end)

	-- Handle player disconnection - cleanup lots and release claims
	Players.PlayerRemoving:Connect(function(player)
		self:_CleanupPlayerLot(player)
	end)

	-- Register ECS sync system with the Planck scheduler
	ServerScheduler:RegisterSystem(function()
		self.GameObjectSyncService:SyncDirtyEntities()
	end, "LotSync")
end

--[=[
	Claim a lot area and spawn the lot model for a player.
	Orchestrates world area claim, entity spawn, and remote lot synchronization.
	@within LotContext
	@param player Player -- The player requesting a lot spawn
	@return Result<{LotId: string, CFrame: CFrame}> -- Ok(result) with lot ID and world CFrame, or Err
]=]
function LotContext:SpawnLot(player: Player): Result.Result<{ LotId: string, CFrame: CFrame }>
	local claimResult = nil

	return Catch(function()
		-- Step 1: Claim a lot area from WorldContext
		claimResult = Try(self.WorldContext:ClaimLotArea(player))
		if not claimResult then
			Try(Err("ClaimFailed", "No available lot areas"))
		end

		-- Step 2: Spawn lot at the claimed CFrame
		local lotId = Try(self.SpawnLotService:Execute(player, claimResult.CFrame))

		-- Flush dirty entities so zone sub-entities exist before remote lot spawns.
		self.GameObjectSyncService:SyncDirtyEntities()
		self:_RegisterLotModel(player, lotId)

		-- Spawn remote lot synchronously before emitting LotSpawned so that
		-- remote zone ECS entities (Mines, Farm, etc.) are registered before
		-- WorkerContext hydrates worker assignments on LotSpawned.
		self.RemoteLotContext:SpawnRemoteLot(player)

		GameEvents.Bus:Emit(Events.Lot.LotSpawned, player.UserId)
		self:_MovePlayerToOnPlaySpawn(player)

		return Ok({ LotId = lotId, CFrame = claimResult.CFrame })
	end, "LotContext:SpawnLot")
end

-- Assign player to the OnPlay team and load character. Used after successful lot spawn.
function LotContext:_MovePlayerToOnPlaySpawn(player: Player)
	local assigned = self:_AssignPlayerToTeamByName(player, ON_PLAY_TEAM_NAME)
	if assigned then
		player:LoadCharacter()
	end
end

-- Assign a player to a team by name. Returns true if successful, false if team not found.
function LotContext:_AssignPlayerToTeamByName(player: Player, teamName: string): boolean
	local team = Teams:FindFirstChild(teamName)
	if not team or not team:IsA("Team") then
		warn(string.format("[LotContext] Team '%s' not found. Player will use default spawn behavior.", teamName))
		return false
	end

	player.Team = team
	player.Neutral = false
	return true
end

--[=[
	Clean up lot model and release area claim when player leaves.
	@within LotContext
	@param player Player -- The player who left
]=]
function LotContext:_CleanupPlayerLot(player: Player)
	local lotTeleportConnection = self.LotTeleportConnections[player]
	if lotTeleportConnection then
		lotTeleportConnection:Disconnect()
		self.LotTeleportConnections[player] = nil
	end
	self.PlayerToLotModel[player] = nil
	self.LotTeleportDebounce[player.UserId] = nil

	-- Step 1: Cleanup lot model and entity
	Catch(function()
		return self.CleanupLotService:Execute(player)
	end, "LotContext:_CleanupPlayerLot")

	-- Step 2: Release the area claim in WorldContext (always runs, even if cleanup failed)
	if self.WorldContext then
		self.WorldContext:ReleaseLotArea(player)
	end
end

-- Register lot model and wire up teleport trigger for a player's lot.
function LotContext:_RegisterLotModel(player: Player, lotId: string)
	local lotModel = workspace:FindFirstChild("Lots")
	if not lotModel then
		warn("[LotContext] Missing workspace.Lots folder when registering teleport")
		return
	end

	local model = (lotModel :: Folder):FindFirstChild("Lot_" .. lotId) :: Model?
	if not model then
		warn("[LotContext] Missing lot model for teleport wiring")
		return
	end

	self.PlayerToLotModel[player] = model
	self:_ConnectLotTeleport(player, model)
end

-- Connect Teleport part touch signal to handle lot entry. Replaces existing connection if present.
function LotContext:_ConnectLotTeleport(player: Player, model: Model)
	local existingConnection = self.LotTeleportConnections[player]
	if existingConnection then
		existingConnection:Disconnect()
	end

	local teleportPart = model:FindFirstChild("Teleport", true) :: BasePart?
	if not teleportPart then
		warn("[LotContext] Teleport part missing on lot model")
		self.LotTeleportConnections[player] = nil
		return
	end

	self.LotTeleportConnections[player] = teleportPart.Touched:Connect(function(hitPart: BasePart)
		self:_HandleLotTeleportTouched(player.UserId, hitPart)
	end)
end

-- Handle teleport touch event. Validates player, applies cooldown, and teleports to remote lot spawn.
function LotContext:_HandleLotTeleportTouched(ownerUserId: number, hitPart: BasePart)
	local touchPlayer = self:_GetTouchPlayer(hitPart)
	if not touchPlayer or touchPlayer.UserId ~= ownerUserId then
		return
	end

	-- Apply teleport cooldown to prevent spam/glitches from multiple touches
	local now = os.clock()
	local lastTeleportTime = self.LotTeleportDebounce[ownerUserId] or 0
	if now - lastTeleportTime < TELEPORT_COOLDOWN_SECONDS then
		return
	end
	self.LotTeleportDebounce[ownerUserId] = now

	local character = touchPlayer.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Get remote lot spawn position from RemoteLotContext
	local player = game:GetService("Players"):GetPlayerByUserId(ownerUserId)
	local spawnCFrame = player and self.RemoteLotContext:GetRemoteLotSpawnCFrame(player)
	if not spawnCFrame then
		warn("[LotContext] Remote lot spawn CFrame missing for teleport")
		return
	end

	-- Teleport player to remote lot
	humanoidRootPart.CFrame = spawnCFrame
	MentionSuccess("LotContext:TeleportToRemoteLot", "Teleported player from village lot to remote lot", {
		userId = ownerUserId,
	})
end

-- Extract player from hitPart's parent character hierarchy. Returns nil if no character or humanoid found.
function LotContext:_GetTouchPlayer(hitPart: BasePart): Player?
	local character = hitPart.Parent
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

--[=[
	Get the Mines folder for a player's lot.
	Used by WorkerContext to validate ore assignments.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Mines folder, or nil if player has no lot
]=]
function LotContext:GetMinesFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindMinesFolderByUserId(userId)
end

--[=[
	Get the Farm folder for a player's lot.
	Used by WorkerContext to validate crop assignments.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Farm folder, or nil if player has no lot or no farm zone
]=]
function LotContext:GetFarmFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindFarmFolderByUserId(userId)
end

--[=[
	Get the Garden folder for a player's lot.
	Used by WorkerContext to validate plant assignments.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Garden folder, or nil if player has no lot or no garden zone
]=]
function LotContext:GetGardenFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindGardenFolderByUserId(userId)
end

--[=[
	Get the Forest folder for a player's lot.
	Used by WorkerContext to validate tree assignments.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Forest folder, or nil if player has no lot or no forest zone
]=]
function LotContext:GetForestFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindForestFolderByUserId(userId)
end

--[=[
	Get the Forge folder for a player's lot.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Forge folder, or nil if player has no lot or no forge zone
]=]
function LotContext:GetForgeFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindForgeFolderByUserId(userId)
end

--[=[
	Get the Brewery folder for a player's lot.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The Brewery folder, or nil if player has no lot or no brewery zone
]=]
function LotContext:GetBreweryFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindBreweryFolderByUserId(userId)
end

--[=[
	Get the TailorShop folder for a player's lot.
	@within LotContext
	@param userId number -- The player's userId
	@return Folder -- The TailorShop folder, or nil if player has no lot or no tailor shop zone
]=]
function LotContext:GetTailorShopFolderForUser(userId: number): Folder?
	return self.EntityFactory:FindTailorShopFolderByUserId(userId)
end

--[=[
	Get the spawn position CFrame for a player's lot.
	Used by DungeonContext to teleport player back after expedition.
	@within LotContext
	@param userId number -- The player's userId
	@return CFrame -- The lot's base CFrame, or nil if player has no lot
]=]
function LotContext:GetLotSpawnPosition(userId: number): CFrame?
	local entity = self:_FindVillageLotEntityByUserId(userId)
	if not entity then
		return nil
	end

	local position = self.World:get(entity, self.Components.PositionComponent)
	if not position then
		return nil
	end

	return position.CFrameValue
end

-- Query ECS world to find village lot entity (excludes RemoteLot_* entries).
function LotContext:_FindVillageLotEntityByUserId(userId: number): any?
	for entity in self.World:query(self.Components.LotComponent) do
		local lotData = self.World:get(entity, self.Components.LotComponent)
		if lotData.UserId == userId and not string.find(lotData.LotId, "RemoteLot_") then
			return entity
		end
	end

	return nil
end

--[=[
	Client-callable method to spawn a lot for a player.
	@within LotContext
	@param player Player -- The player requesting a lot spawn
	@return Result<{LotId: string, CFrame: CFrame}> -- Ok(result) with lot ID and world CFrame, or Err
]=]
function LotContext.Client:SpawnLot(player: Player)
	return self.Server:SpawnLot(player)
end

WrapContext(LotContext, "LotContext")

return LotContext
