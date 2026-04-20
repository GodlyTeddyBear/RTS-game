--!strict

--[=[
	@class RemoteLotContext
	Manages the secondary remote lot per player.
	@server
]=]

--[[
	The remote lot is a separate model placed on remote terrain that holds
	the Farm, Garden, Forest, and Mines zones. It registers its zone folders
	into the same Lot ECS world so LotContext's zone folder getters resolve
	remote zones transparently — BuildingContext never needs to know the difference.

	Lifecycle:
	  - SpawnRemoteLot runs immediately after SpawnLot (on LotSpawned event)
	  - CleanupRemoteLot runs on PlayerRemoving alongside village lot cleanup
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Result = require(ReplicatedStorage.Utilities.Result)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Catch, Try = Result.Catch, Result.Try
local MentionSuccess = Result.MentionSuccess

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

-- Infrastructure
local RemoteLotEntityFactory = require(script.Parent.Infrastructure.ECS.RemoteLotEntityFactory)
local RemoteLotModelFactory = require(script.Parent.Infrastructure.Services.RemoteLotModelFactory)
local RemoteLotRevealService = require(script.Parent.Infrastructure.Services.RemoteLotRevealService)
local RemoteLotTerrainTemplate = require(script.Parent.Infrastructure.Services.RemoteLotTerrainTemplate)
local RemoteLotTracker = require(script.Parent.Infrastructure.Persistence.RemoteLotTracker)
local RemoteLotAreaConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotAreaConfig)

-- Application Commands
local SpawnRemoteLot = require(script.Parent.Application.Commands.SpawnRemoteLot)
local CleanupRemoteLot = require(script.Parent.Application.Commands.CleanupRemoteLot)
local PurchaseAreaExpansion = require(script.Parent.Application.Commands.PurchaseAreaExpansion)

local RemoteLotContext = Knit.CreateService({
	Name = "RemoteLotContext",
	Client = {},
})

local TELEPORT_COOLDOWN_SECONDS = 1

function RemoteLotContext:KnitInit()
	-- Initialize the registry and state tables
	self.Registry = Registry.new("Server")
	self.RemoteTeleportConnections = {} :: { [Player]: RBXScriptConnection }
	self.RemoteTeleportDebounce = {} :: { [number]: number }

	-- Bootstrap infrastructure and commands
	local remoteLotFolder = self:_EnsureRemoteLotFolder()
	self:_RegisterInfrastructure(remoteLotFolder)
	self:_RegisterCommands()
	self:_InitEarlyServices()
	self:_CacheServiceRefs()
end

-- Finds or creates the RemoteLots folder in workspace where all remote lot models live.
function RemoteLotContext:_EnsureRemoteLotFolder(): Folder
	local folder = workspace:FindFirstChild("RemoteLots") :: Folder?
	if not folder then
		-- Create and parent the folder on first run
		folder = Instance.new("Folder")
		folder.Name = "RemoteLots"
		folder.Parent = workspace
	end
	return folder
end

-- Registers all infrastructure services into the registry.
function RemoteLotContext:_RegisterInfrastructure(remoteLotFolder: Folder)
	local registry = self.Registry
	registry:Register("RemoteLotTracker", RemoteLotTracker.new(), "Infrastructure")
	registry:Register("RemoteLotModelFactory", RemoteLotModelFactory.new(remoteLotFolder), "Infrastructure")
	registry:Register("RemoteLotRevealService", RemoteLotRevealService.new(), "Infrastructure")
	registry:Register("RemoteLotTerrainTemplate", RemoteLotTerrainTemplate.new(), "Infrastructure")
	-- EntityFactory.Init needs LotWorld + LotComponents from LotContext — injected in KnitStart
	registry:Register("RemoteLotEntityFactory", RemoteLotEntityFactory.new(), "Infrastructure")
end

-- Registers all application commands into the registry.
function RemoteLotContext:_RegisterCommands()
	local registry = self.Registry
	registry:Register("SpawnRemoteLot", SpawnRemoteLot.new(), "Application")
	registry:Register("CleanupRemoteLot", CleanupRemoteLot.new(), "Application")
	registry:Register("PurchaseAreaExpansion", PurchaseAreaExpansion.new(), "Application")
end

-- Initializes services that have no cross-context dependencies.
-- EntityFactory, SpawnRemoteLot, and CleanupRemoteLot are initialized in KnitStart after LotContext is available.
function RemoteLotContext:_InitEarlyServices()
	local registry = self.Registry
	registry:Get("RemoteLotTracker"):Init(registry, "RemoteLotTracker")
	registry:Get("RemoteLotTerrainTemplate"):Init(registry, "RemoteLotTerrainTemplate")
	registry:Get("RemoteLotModelFactory"):Init(registry, "RemoteLotModelFactory")
	registry:Get("RemoteLotRevealService"):Init(registry, "RemoteLotRevealService")
end

-- Caches service references from the registry for quick access.
function RemoteLotContext:_CacheServiceRefs()
	local registry = self.Registry
	self.Tracker = registry:Get("RemoteLotTracker")
	self.ModelFactory = registry:Get("RemoteLotModelFactory")
	self.RevealService = registry:Get("RemoteLotRevealService")
	self.EntityFactory = registry:Get("RemoteLotEntityFactory")
	self.SpawnCommand = registry:Get("SpawnRemoteLot")
	self.CleanupCommand = registry:Get("CleanupRemoteLot")
	self.PurchaseCommand = registry:Get("PurchaseAreaExpansion")
end

function RemoteLotContext:KnitStart()
	-- Wire cross-context dependencies from LotContext
	self:_WireLotContextDependencies()
	self:_WireUnlockContextDependencies()
	-- Initialize application commands
	self:_InitApplicationCommands()
	-- Connect player lifecycle handlers
	self:_ConnectPlayerLifecycle()
end

-- Injects the Lot ECS world and components into EntityFactory so remote zone entities register into the same world.
function RemoteLotContext:_WireLotContextDependencies()
	local lotContext = Knit.GetService("LotContext")
	self.LotContext = lotContext
	self.EntityFactory:InjectLotWorld(lotContext.World, lotContext.Components)
end

function RemoteLotContext:_WireUnlockContextDependencies()
	self.UnlockContext = Knit.GetService("UnlockContext")
	self.Registry:Register("UnlockContext", self.UnlockContext)
end

-- Initializes application commands now that registry is fully populated.
function RemoteLotContext:_InitApplicationCommands()
	self.SpawnCommand:Init(self.Registry, "SpawnRemoteLot")
	self.CleanupCommand:Init(self.Registry, "CleanupRemoteLot")
	self.PurchaseCommand:Init(self.Registry, "PurchaseAreaExpansion")
end

-- Connects to PlayerRemoving to tear down remote lots on disconnect.
function RemoteLotContext:_ConnectPlayerLifecycle()
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_CleanupRemoteLot(player)
	end)
end

--[=[
	Spawns the remote lot for a player.
	Called directly by LotContext:SpawnLot before LotSpawned fires so remote zone
	ECS entities exist before WorkerContext hydrates assignments.
	@within RemoteLotContext
	@param player Player
]=]
function RemoteLotContext:SpawnRemoteLot(player: Player)
	Catch(function()
		-- Execute spawn command to create the model and ECS entities
		Try(self.SpawnCommand:Execute(player))
		self:_ApplyUnlockedExpansions(player)
		-- Wire up teleport zone detection
		self:_WireRemoteTeleport(player)
	end, "RemoteLotContext:SpawnRemoteLot")
end

function RemoteLotContext:_ApplyUnlockedExpansions(player: Player)
	local model = self.Tracker:GetModel(player)
	local entity = self.EntityFactory:FindRemoteLotByUserId(player.UserId)
	if not model or not entity then
		return
	end

	for _, areaDef in RemoteLotAreaConfig do
		if self.UnlockContext:IsUnlocked(player.UserId, areaDef.TargetId) then
			self.RevealService:RevealArea(model, areaDef)
			self.EntityFactory:RegisterExpansionZones(entity, model, areaDef)
		end
	end
end

--[=[
	Purchases and reveals a remote lot expansion area.
	@within RemoteLotContext
	@param player Player -- The player purchasing the expansion
	@param areaId string -- Configured remote lot area id
	@return Result.Result<boolean>
]=]
function RemoteLotContext:PurchaseAreaExpansion(player: Player, areaId: string): Result.Result<boolean>
	return Catch(function()
		return self.PurchaseCommand:Execute(player, areaId)
	end, "RemoteLotContext:PurchaseAreaExpansion")
end

-- Connects the teleport zone on the remote lot model to player touch detection.
function RemoteLotContext:_WireRemoteTeleport(player: Player)
	local model = self.Tracker:GetModel(player)
	if model then
		self:_ConnectRemoteTeleport(player, model)
	else
		warn("[RemoteLotContext] Missing remote lot model for teleport wiring")
	end
end

-- Tears down teleport connection and executes cleanup command on player disconnect.
function RemoteLotContext:_CleanupRemoteLot(player: Player)
	-- Disconnect teleport touch listener
	local remoteTeleportConnection = self.RemoteTeleportConnections[player]
	if remoteTeleportConnection then
		remoteTeleportConnection:Disconnect()
		self.RemoteTeleportConnections[player] = nil
	end
	-- Clear debounce state for this player
	self.RemoteTeleportDebounce[player.UserId] = nil

	-- Execute cleanup command to destroy model and ECS entities
	Catch(function()
		return self.CleanupCommand:Execute(player)
	end, "RemoteLotContext:_CleanupRemoteLot")
end

-- Connects the teleport part touch detector to the teleport handler.
function RemoteLotContext:_ConnectRemoteTeleport(player: Player, model: Model)
	-- Disconnect any existing connection to avoid duplicates
	local existingConnection = self.RemoteTeleportConnections[player]
	if existingConnection then
		existingConnection:Disconnect()
	end

	-- Find the teleport part on the model
	local teleportPart = model:FindFirstChild("Teleport", true) :: BasePart?
	if not teleportPart then
		warn("[RemoteLotContext] Teleport part missing on remote lot model")
		self.RemoteTeleportConnections[player] = nil
		return
	end

	-- Wire touch detection to handler
	self.RemoteTeleportConnections[player] = teleportPart.Touched:Connect(function(hitPart: BasePart)
		self:_HandleRemoteTeleportTouched(player.UserId, hitPart)
	end)
end

-- Processes a touch on the teleport zone, validating ownership and cooldown before teleporting.
function RemoteLotContext:_HandleRemoteTeleportTouched(ownerUserId: number, hitPart: BasePart)
	-- Get the player who touched the zone
	local touchPlayer = self:_GetTouchPlayer(hitPart)
	-- Ignore touches from other players
	if not touchPlayer or touchPlayer.UserId ~= ownerUserId then
		return
	end
	-- Ignore if cooldown hasn't elapsed
	if not self:_TryConsumeTeleportCooldown(ownerUserId) then
		return
	end
	-- Execute teleport to village lot
	self:_TeleportPlayerToVillageLot(touchPlayer, ownerUserId)
end

-- Checks if the teleport cooldown has elapsed and updates the cooldown timestamp.
function RemoteLotContext:_TryConsumeTeleportCooldown(userId: number): boolean
	local now = os.clock()
	if now - (self.RemoteTeleportDebounce[userId] or 0) < TELEPORT_COOLDOWN_SECONDS then
		return false
	end
	self.RemoteTeleportDebounce[userId] = now
	return true
end

-- Teleports a player from the remote lot back to their village lot spawn point.
function RemoteLotContext:_TeleportPlayerToVillageLot(player: Player, ownerUserId: number)
	-- Guard: character must exist
	local character = player.Character
	if not character then
		return
	end

	-- Guard: character must have HumanoidRootPart
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Fetch spawn position from LotContext
	local lotCFrame = self.LotContext:GetLotSpawnPosition(ownerUserId)
	if not lotCFrame then
		warn("[RemoteLotContext] Lot CFrame missing for teleport")
		return
	end

	-- Teleport player with 5-stud vertical offset
	humanoidRootPart.CFrame = lotCFrame + Vector3.new(0, 5, 0)
	MentionSuccess("RemoteLotContext:TeleportToVillageLot", "Teleported player from remote lot to village lot", {
		userId = ownerUserId,
	})
end

-- Extracts the Player from a part that was touched, if it's part of a character.
function RemoteLotContext:_GetTouchPlayer(hitPart: BasePart): Player?
	-- Get the parent (character model)
	local character = hitPart.Parent
	if not character then
		return nil
	end

	-- Verify character has humanoid
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	-- Resolve character to player
	return game:GetService("Players"):GetPlayerFromCharacter(character)
end

--[=[
	Returns the CFrame of the player's remote lot.
	@within RemoteLotContext
	@param userId number
	@return CFrame? -- The remote lot CFrame, or nil if not found
]=]
function RemoteLotContext:GetRemoteLotCFrame(userId: number): CFrame?
	local entity = self.EntityFactory:FindRemoteLotByUserId(userId)
	if not entity then
		return nil
	end
	return self.EntityFactory:GetLotCFrame(entity)
end

--[=[
	Returns the spawn CFrame for the player's remote lot SpawnPoint.
	Falls back to the lot CFrame if no SpawnPoint was found on the model.
	@within RemoteLotContext
	@param player Player
	@return CFrame? -- The spawn point CFrame, or nil if not found
]=]
function RemoteLotContext:GetRemoteLotSpawnCFrame(player: Player): CFrame?
	return self.Tracker:GetSpawnCFrame(player)
end

--[=[
	@method Client:GetRemoteLotCFrame
	@within RemoteLotContext
	@param player Player
	@return CFrame? -- The remote lot CFrame, or nil if not found
]=]
function RemoteLotContext.Client:GetRemoteLotCFrame(player: Player)
	return self.Server:GetRemoteLotCFrame(player.UserId)
end

function RemoteLotContext.Client:PurchaseAreaExpansion(player: Player, areaId: string)
	return self.Server:PurchaseAreaExpansion(player, areaId)
end

WrapContext(RemoteLotContext, "RemoteLotContext")

return RemoteLotContext
