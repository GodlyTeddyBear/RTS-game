--!strict

--[[
	UnlockConfig — Aggregated unlock definitions from owning bounded contexts.

	Do not add domain slices here. Add entries in the owning context and require
	its export below. See `.claude/documents/architecture/UNLOCK_REGISTRY.md`.

	Types: `Unlock.Types.UnlockEntryTypes`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnlockEntryTypes = require(script.Parent.Parent.Types.UnlockEntryTypes)

local ItemUnlockConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemUnlockConfig)
local BuildingUnlockConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingUnlockConfig)
local RoleUnlockConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleUnlockConfig)
local OreUnlockConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreUnlockConfig)
local TreeUnlockConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeUnlockConfig)
local ZoneUnlockConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneUnlockConfig)
local CommissionTierUnlockConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionTierUnlockConfig)
local RemoteLotAreaUnlockConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotAreaUnlockConfig)

local config: { [string]: UnlockEntryTypes.TUnlockEntry } = {}

for _, mod in
	{
		ItemUnlockConfig,
		BuildingUnlockConfig,
		RoleUnlockConfig,
		OreUnlockConfig,
		TreeUnlockConfig,
		ZoneUnlockConfig,
		CommissionTierUnlockConfig,
		RemoteLotAreaUnlockConfig,
	}
do
	for k, v in mod do
		config[k] = v
	end
end

return table.freeze(config)
