--!strict

--[[
	World Context - Main Knit service managing world lot areas and claims

	DDD Architecture:
	- Domain Layer: Specs (LotAreaSpecs), Policies (ClaimPolicy, ReleasePolicy)
	- Application Layer: Orchestration (ClaimLotAreaService, ReleaseLotAreaService, FindAvailableLotAreasService)
	- Infrastructure Layer: Technical implementation (LotAreaRegistry)

	Context Layer Responsibility:
	- Initialize all layers via Registry pattern
	- Knit lifecycle management
	- Pure bridges to Application services (no business logic)
]]

--[=[
	@class WorldContext
	Main Knit service managing world lot areas and player claims.
	Initializes DDD layers, discovers lot areas, and orchestrates claim/release workflows.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local Result = require(ReplicatedStorage.Utilities.Result)
local Catch = Result.Catch
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Registry = require(ReplicatedStorage.Utilities.Registry)

-- Infrastructure services
local LotAreaRegistry = require(script.Parent.Infrastructure.Services.LotAreaRegistry)

-- Domain policies
local ClaimPolicy = require(script.Parent.WorldDomain.Policies.ClaimPolicy)
local ReleasePolicy = require(script.Parent.WorldDomain.Policies.ReleasePolicy)

-- Application Commands
local ClaimLotAreaService = require(script.Parent.Application.Commands.ClaimLotAreaService)
local ReleaseLotAreaService = require(script.Parent.Application.Commands.ReleaseLotAreaService)

-- Application Queries
local FindAvailableLotAreasService = require(script.Parent.Application.Queries.FindAvailableLotAreasService)

local WorldContext = Knit.CreateService({
	Name = "WorldContext",
	Client = {},
})

--[[
	KnitInit - Initialize all layers via Registry

	Layer initialization order:
	1. Raw values: asset fetcher registry, workspace folder
	2. Infrastructure: LotAreaRegistry
	3. Domain: ClaimPolicy, ReleasePolicy
	4. Application: ClaimLotAreaService, ReleaseLotAreaService, FindAvailableLotAreasService
]]
function WorldContext:KnitInit()
	local registry = Registry.new("Server")

	-- ====================
	-- RAW VALUES
	-- ====================

	-- Create workspace folder for unclaimed lot models
	local unclaimedLotsFolder = Instance.new("Folder")
	unclaimedLotsFolder.Name = "UnclaimedLots"
	unclaimedLotsFolder.Parent = workspace

	-- Create LotRegistry for unclaimed model cloning
	local lotsAssetsFolder = game:GetService("ReplicatedStorage").Assets:FindFirstChild("Lots")
	if not lotsAssetsFolder then
		warn("[WorldContext] ReplicatedStorage.Assets.Lots folder not found")
	end
	local lotRegistry = AssetFetcher.CreateLotRegistry(lotsAssetsFolder)

	registry:Register("LotRegistry", lotRegistry)

	-- ====================
	-- INFRASTRUCTURE LAYER
	-- ====================

	registry:Register("LotAreaRegistry", LotAreaRegistry.new(unclaimedLotsFolder), "Infrastructure")

	-- ====================
	-- DOMAIN LAYER
	-- ====================

	registry:Register("ClaimPolicy", ClaimPolicy.new(), "Domain")
	registry:Register("ReleasePolicy", ReleasePolicy.new(), "Domain")

	-- ====================
	-- APPLICATION LAYER
	-- ====================

	registry:Register("ClaimLotAreaService", ClaimLotAreaService.new(), "Application")
	registry:Register("ReleaseLotAreaService", ReleaseLotAreaService.new(), "Application")
	registry:Register("FindAvailableLotAreasService", FindAvailableLotAreasService.new(), "Application")

	registry:InitAll()

	-- Cache refs
	self.Registry = registry:Get("LotAreaRegistry")
	self.ClaimLotAreaService = registry:Get("ClaimLotAreaService")
	self.ReleaseLotAreaService = registry:Get("ReleaseLotAreaService")
	self.FindAvailableLotAreasService = registry:Get("FindAvailableLotAreasService")

	local discoveryResult = self.Registry:DiscoverAreas()
	if discoveryResult.success then
		print(`[WorldContext] Discovered {discoveryResult.value} lot areas`)
	else
		warn(`[WorldContext] Failed to discover lot areas: {discoveryResult.message}`)
	end
end

--[[
	KnitStart - Hook up lifecycle events
]]
function WorldContext:KnitStart()
	local Players = game:GetService("Players")

	-- Safety net: release claims when players leave
	Players.PlayerRemoving:Connect(function(player)
		self:ReleaseLotArea(player)
	end)
end

-- ====================
-- SERVER API (called by other contexts)
-- ====================

--[=[
	Claim the first available lot area for a player.
	Bridge to the Application layer ClaimLotAreaService.
	@within WorldContext
	@param player Player -- The player requesting the claim
	@return Result.Result<{ AreaName: string, CFrame: CFrame }> -- The claimed area name and spawn CFrame, or error
	@error string -- Thrown if no areas are available or player already has a claim
]=]
function WorldContext:ClaimLotArea(player: Player)
	return Catch(function()
		return self.ClaimLotAreaService:Execute(player)
	end, "World:ClaimLotArea")
end

--[=[
	Release a player's lot area claim.
	Bridge to the Application layer ReleaseLotAreaService.
	Also called automatically when players disconnect.
	@within WorldContext
	@param player Player -- The player releasing their claim
	@return Result.Result<string> -- The released area name, or error if player has no claim
]=]
function WorldContext:ReleaseLotArea(player: Player)
	return Catch(function()
		return self.ReleaseLotAreaService:Execute(player)
	end, "World:ReleaseLotArea")
end

--[=[
	Get all lot areas with their current availability status.
	Bridge to the Application layer FindAvailableLotAreasService.
	@within WorldContext
	@return Result.Result<{ { Name: string, IsClaimed: boolean } }> -- All areas with claim status
]=]
function WorldContext:GetAvailableAreas()
	return Catch(function()
		return self.FindAvailableLotAreasService:Execute()
	end, "World:GetAvailableAreas")
end

-- ====================
-- CLIENT API
-- ====================

--[=[
	Get all lot areas with their availability status.
	Client-facing method that queries the server.
	@within WorldContext
	@param player Player -- The requesting player
	@return Result.Result<{ { Name: string, IsClaimed: boolean } }> -- All areas with claim status
]=]
function WorldContext.Client:GetLotAreas(player: Player)
	return Catch(function()
		return self.Server:GetAvailableAreas()
	end, "World.Client:GetLotAreas")
end

WrapContext(WorldContext, "WorldContext")

return WorldContext
