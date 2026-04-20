--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels

--- Server stores all players' upgrade levels, indexed by UserId
export type TPlayerUpgrades = {
	[number]: TUpgradeLevels,
}

--- Creates server-side atom for all players' upgrade levels
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerUpgrades)
end

--- Creates client-side atom for current player's upgrade levels only
local function CreateClientAtom()
	return Charm.atom(nil :: TUpgradeLevels?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
