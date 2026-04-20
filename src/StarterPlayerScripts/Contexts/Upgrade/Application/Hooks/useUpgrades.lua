--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels

local useAtom = ReactCharm.useAtom

--[=[
	@function useUpgrades
	Read hook that subscribes to the upgrade levels atom. Returns `{ [upgradeId] = level }`.
	@return TUpgradeLevels
]=]
local function useUpgrades(): TUpgradeLevels
	local upgradeController = Knit.GetController("UpgradeController")
	if not upgradeController then
		warn("useUpgrades: UpgradeController not available")
		return {}
	end
	local upgradesAtom = upgradeController:GetUpgradesAtom()
	local atomValue = useAtom(upgradesAtom)
	if atomValue == nil then
		return {}
	end
	if atomValue.upgrades ~= nil then
		return atomValue.upgrades
	end
	return atomValue
end

return useUpgrades
