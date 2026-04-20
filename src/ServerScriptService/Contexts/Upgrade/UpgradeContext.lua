--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.UpgradeSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local UpgradeConfig = require(ReplicatedStorage.Contexts.Upgrade.Config.UpgradeConfig)

local Catch = Result.Catch
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain
local ModifierAggregator = require(script.Parent.UpgradeDomain.Services.ModifierAggregator)
local PurchaseUpgradePolicy = require(script.Parent.UpgradeDomain.Policies.PurchaseUpgradePolicy)

-- Infrastructure
local UpgradeSyncService = require(script.Parent.Infrastructure.Persistence.UpgradeSyncService)
local UpgradePersistenceService = require(script.Parent.Infrastructure.Persistence.UpgradePersistenceService)

-- Application
local PurchaseUpgrade = require(script.Parent.Application.Commands.PurchaseUpgrade)

--[=[
	@class UpgradeContext
	Knit service for the Upgrade bounded context.

	Owns player-purchased upgrade levels, exposes a generic `GetModifier` query
	for other contexts to consume at effect time, and handles the
	`PurchaseUpgrade` client write path.
	@server
]=]
local UpgradeContext = Knit.CreateService({
	Name = "UpgradeContext",
	Client = {},
})

---
-- Knit Lifecycle
---

--[=[
	@within UpgradeContext
	@private
]=]
function UpgradeContext:KnitInit()
	local registry = Registry.new("Server")

	-- Raw values
	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("UpgradeContext")

	-- Domain
	registry:Register("ModifierAggregator", ModifierAggregator.new(), "Domain")
	registry:Register("PurchaseUpgradePolicy", PurchaseUpgradePolicy.new(), "Domain")

	-- Infrastructure
	registry:Register("UpgradeSyncService", UpgradeSyncService.new(), "Infrastructure")
	registry:Register("UpgradePersistenceService", UpgradePersistenceService.new(), "Infrastructure")

	-- Application
	registry:Register("PurchaseUpgradeService", PurchaseUpgrade.new(), "Application")

	registry:InitAll()

	self.ModifierAggregator = registry:Get("ModifierAggregator")
	self.UpgradeSyncService = registry:Get("UpgradeSyncService")
	self.UpgradePersistenceService = registry:Get("UpgradePersistenceService")
	self.PurchaseUpgradeService = registry:Get("PurchaseUpgradeService")

	self._registry = registry
end

--[=[
	@within UpgradeContext
	@private
]=]
function UpgradeContext:KnitStart()
	-- Cross-context dependencies
	self._registry:Register("ShopContext", Knit.GetService("ShopContext"))

	self._registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Load upgrade atom when profile becomes available
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadUpgradeAtom(player)
				PlayerLifecycleManager:NotifyLoaded(player, "UpgradeContext")
			end)
			:catch(function(err)
				warn("[UpgradeContext] Failed to load player data:", tostring(err))
			end)
	end)

	-- Hydrate client once player is ready
	GameEvents.Bus:On(Events.Persistence.PlayerReady, function(player)
		task.spawn(function()
			self.UpgradeSyncService:HydratePlayer(player)
		end)
	end)

	-- Persist and clear atom on save
	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self:_CleanupOnPlayerLeave(player)
	end)
end

---
-- Player Data Loading
---

--[=[
	@within UpgradeContext
	@private
]=]
function UpgradeContext:_LoadUpgradeAtom(player: Player)
	local userId = player.UserId
	local levels = self.UpgradePersistenceService:LoadUpgradeData(player)
	self.UpgradeSyncService:LoadUserUpgrades(userId, levels)
end

--[=[
	@within UpgradeContext
	@private
]=]
function UpgradeContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId
	local levels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	if levels then
		self.UpgradePersistenceService:SaveUpgradeData(player, levels)
	end
	self.UpgradeSyncService:RemoveUserUpgrades(userId)
end

---
-- Server-to-Server API
---

--[=[
	Returns the multiplier `1 + sum(effect * level)` for a given modifier id.
	Returns `1` when the player's state is not loaded, so consumers degrade gracefully.
	@within UpgradeContext
	@param userId number
	@param modifierId string
	@return number
]=]
function UpgradeContext:GetModifier(userId: number, modifierId: string): number
	local levels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	if not levels then
		return 1
	end
	local additive = self.ModifierAggregator:Aggregate(levels, modifierId)
	return 1 + additive
end

--[=[
	Gold income multiplier (>= 1).
	@within UpgradeContext
	@param userId number
	@return number
]=]
function UpgradeContext:GetGoldMultiplier(userId: number): number
	return self:GetModifier(userId, "GoldMultiplier")
end

--[=[
	Worker XP gain multiplier (>= 1).
	@within UpgradeContext
	@param userId number
	@return number
]=]
function UpgradeContext:GetWorkerXPMultiplier(userId: number): number
	return self:GetModifier(userId, "WorkerXPMultiplier")
end

--[=[
	Shop purchase discount as a fraction in [0, MaxDiscount]. Returns 0 when not loaded.
	@within UpgradeContext
	@param userId number
	@return number
]=]
function UpgradeContext:GetShopDiscount(userId: number): number
	local levels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	if not levels then
		return 0
	end
	local additive = self.ModifierAggregator:Aggregate(levels, "ShopDiscount")
	return math.clamp(additive, 0, UpgradeConfig.MaxDiscount)
end

--[=[
	Returns the upgrade-cost discount applied when pricing `upgradeIdBeingPriced`.
	Guards against self-discount: the UpgradeCostDiscount upgrade never discounts itself.
	@within UpgradeContext
	@param userId number
	@param upgradeIdBeingPriced string
	@return number
]=]
function UpgradeContext:GetUpgradeCostDiscount(userId: number, upgradeIdBeingPriced: string): number
	local levels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	if not levels then
		return 0
	end
	local additive = self.ModifierAggregator:Aggregate(
		levels,
		"UpgradeCostDiscount",
		upgradeIdBeingPriced
	)
	return math.clamp(additive, 0, UpgradeConfig.MaxDiscount)
end

--[=[
	Deep-clones the player's current upgrade levels for read-only consumption.
	@within UpgradeContext
	@param userId number
	@return { [string]: number }?
]=]
function UpgradeContext:GetUpgradeLevelsReadOnly(userId: number)
	return self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
end

--[=[
	Initiates a player-purchased upgrade level.
	@within UpgradeContext
	@param player Player
	@param upgradeId string
	@return Result.Result<any>
]=]
function UpgradeContext:PurchaseUpgrade(player: Player, upgradeId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.PurchaseUpgradeService:Execute(player, userId, upgradeId)
	end, "Upgrade:PurchaseUpgrade")
end

---
-- Client API
---

--[=[
	@within UpgradeContext
	@client
]=]
function UpgradeContext.Client:PurchaseUpgrade(player: Player, upgradeId: string)
	return self.Server:PurchaseUpgrade(player, upgradeId)
end

--[=[
	@within UpgradeContext
	@client
]=]
function UpgradeContext.Client:RequestUpgradeState(player: Player)
	self.Server.UpgradeSyncService:HydratePlayer(player)
	return true
end

--[=[
	@within UpgradeContext
	@client
]=]
function UpgradeContext.Client:GetUpgradeCatalog(_player: Player)
	return UpgradeConfig.Entries
end

WrapContext(UpgradeContext, "UpgradeContext")

return UpgradeContext
