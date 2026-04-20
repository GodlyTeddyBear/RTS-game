--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local UpgradeSyncClient = require(script.Parent.Infrastructure.UpgradeSyncClient)

--[=[
	@class UpgradeController
	Knit controller managing client-side upgrade state subscription and purchase actions.
	@client
]=]
local UpgradeController = Knit.CreateController({
	Name = "UpgradeController",
})

function UpgradeController:KnitInit()
	self._Registry = Registry.new("Client")
	self._Registry:Register("UpgradeSyncClient", UpgradeSyncClient.new(), "Infrastructure")
	self._Registry:InitAll()

	self.SyncClient = self._Registry:Get("UpgradeSyncClient")
end

function UpgradeController:KnitStart()
	local upgradeContext = Knit.GetService("UpgradeContext")
	self._Registry:Register("UpgradeContext", upgradeContext)
	self.UpgradeContext = upgradeContext

	self._Registry:StartOrdered({ "Infrastructure" })

	task.delay(0.3, function()
		self:RequestUpgradeState()
	end)
end

--[=[
	@within UpgradeController
	Returns the Charm atom holding the current player's upgrade levels.
]=]
function UpgradeController:GetUpgradesAtom()
	return self.SyncClient:GetUpgradesAtom()
end

--[=[
	@within UpgradeController
	Requests a fresh hydration of upgrade state from the server.
]=]
function UpgradeController:RequestUpgradeState()
	return self.UpgradeContext:RequestUpgradeState()
end

--[=[
	@within UpgradeController
	Purchases the next level of an upgrade.
	@param upgradeId string
]=]
function UpgradeController:PurchaseUpgrade(upgradeId: string)
	return self.UpgradeContext:PurchaseUpgrade(upgradeId)
		:catch(function(err)
			warn("[UpgradeController:PurchaseUpgrade]", err.type, err.message)
		end)
end

return UpgradeController
