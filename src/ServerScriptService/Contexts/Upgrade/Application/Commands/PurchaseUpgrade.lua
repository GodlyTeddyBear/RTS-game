--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[=[
	@class PurchaseUpgrade
	Player-initiated upgrade level purchase. Validates eligibility via
	`PurchaseUpgradePolicy`, deducts gold, increments the upgrade level,
	persists to the profile, and syncs to the client.
	@server
]=]

local PurchaseUpgrade = {}
PurchaseUpgrade.__index = PurchaseUpgrade

function PurchaseUpgrade.new()
	return setmetatable({}, PurchaseUpgrade)
end

--[=[
	@within PurchaseUpgrade
	@private
]=]
function PurchaseUpgrade:Init(registry: any, _name: string)
	self.PurchaseUpgradePolicy = registry:Get("PurchaseUpgradePolicy")
	self.UpgradeSyncService = registry:Get("UpgradeSyncService")
	self.UpgradePersistenceService = registry:Get("UpgradePersistenceService")
	self.Registry = registry
end

--[=[
	@within PurchaseUpgrade
	@private
]=]
function PurchaseUpgrade:Start()
	self.ShopContext = self.Registry:Get("ShopContext")
end

--[=[
	Validates inputs, checks policy, deducts gold, increments level, persists, syncs.
	@within PurchaseUpgrade
	@param player Player
	@param userId number
	@param upgradeId string
	@return Result.Result<{ UpgradeId: string, NewLevel: number, Cost: number }>
]=]
function PurchaseUpgrade:Execute(
	player: Player,
	userId: number,
	upgradeId: string
): Result.Result<{ UpgradeId: string, NewLevel: number, Cost: number }>
	self:_ValidateInputs(player, userId, upgradeId)

	local terms = Try(self.PurchaseUpgradePolicy:Check(userId, upgradeId))

	Try(self.ShopContext:DeductGold(player, userId, terms.Cost))

	self:_ApplyPurchase(player, userId, upgradeId, terms.NewLevel)

	MentionSuccess("Upgrade:PurchaseUpgrade:Execute", "Purchased upgrade level", {
		userId = userId,
		upgradeId = upgradeId,
		newLevel = terms.NewLevel,
		cost = terms.Cost,
	})

	return Ok({
		UpgradeId = upgradeId,
		NewLevel = terms.NewLevel,
		Cost = terms.Cost,
	})
end

--[=[
	@within PurchaseUpgrade
	@private
]=]
function PurchaseUpgrade:_ValidateInputs(player: Player, userId: number, upgradeId: string)
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")
	Ensure(type(upgradeId) == "string" and #upgradeId > 0, "InvalidInput", "Invalid upgradeId")
end

--[=[
	@within PurchaseUpgrade
	@private
]=]
function PurchaseUpgrade:_ApplyPurchase(player: Player, userId: number, upgradeId: string, newLevel: number)
	self.UpgradeSyncService:SetUpgradeLevel(userId, upgradeId, newLevel)

	local finalLevels = self.UpgradeSyncService:GetUpgradeLevelsReadOnly(userId)
	if finalLevels then
		Try(self.UpgradePersistenceService:SaveUpgradeData(player, finalLevels))
	end

	self.UpgradeSyncService:HydratePlayer(player)
end

return PurchaseUpgrade
