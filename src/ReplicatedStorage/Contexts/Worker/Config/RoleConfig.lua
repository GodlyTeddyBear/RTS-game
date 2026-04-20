--!strict

--[[
	Role Configuration

	Single source of truth for all worker roles and their stats.

	Adding a new role:
	1. Add a new entry to this config
	2. That's it! No code changes needed.

	To make a role require a target selection (e.g. Miner → ore):
	- Set TargetConfig to the relevant config table (e.g. OreConfig)
	- Nil means no target is needed for this role

	Example:
	Miner = {
		RoleId = "Miner",
		DisplayName = "Miner",
		BaseProductionRate = 2.0,
		LevelScaling = 0.15,
		XPPerProduction = 5,
		BasePay = 3,
		CanProduce = true,
		TargetConfig = OreConfig,
	}
]]

local OreConfig = require(script.Parent.OreConfig)
local TreeConfig = require(script.Parent.TreeConfig)
local PlantConfig = require(script.Parent.PlantConfig)

export type TRoleStats = {
	RoleId: string, -- Unique role identifier
	DisplayName: string, -- Human-readable name for UI
	BaseProductionRate: number, -- Units produced per second at level 1
	LevelScaling: number, -- Production multiplier per level (+10% = 0.1)
	XPPerProduction: number, -- XP gained per unit produced
	BasePay: number, -- Currency cost per tick (future feature)
	CanProduce: boolean, -- Can this role produce?
	TargetConfig: { [string]: { OreId: string, DisplayName: string } }?, -- Target selection config (nil = no target)
	EquipToolId: string?, -- Tool to equip when assigned this role (nil = no tool)
	AnimationState: string?, -- Animation state to play when actively working (nil = "Mining" fallback)
}

return table.freeze({
	Undecided = {
		RoleId = "Undecided",
		DisplayName = "Undecided",
		BaseProductionRate = 0.0, -- No production
		LevelScaling = 0.0, -- No scaling
		XPPerProduction = 0, -- No XP gain
		BasePay = 0,
		CanProduce = false, -- Explicitly marked as non-producing
		TargetConfig = nil,
	} :: TRoleStats,
	Forge = {
		RoleId = "Forge",
		DisplayName = "Blacksmith",
		BaseProductionRate = 1.0, -- 1 weapon/sec at level 1
		LevelScaling = 0.1, -- +10% per level
		XPPerProduction = 10, -- 10 XP per weapon
		BasePay = 5, -- Future: 5 coins per tick
		CanProduce = false,
		TargetConfig = nil,
	} :: TRoleStats,
	Miner = {
		RoleId = "Miner",
		DisplayName = "Miner",
		BaseProductionRate = 2.0,
		LevelScaling = 0.15,
		XPPerProduction = 5,
		BasePay = 3,
		CanProduce = false, -- XP comes from ProcessMinerMining, not the generic production loop
		TargetConfig = OreConfig,
		EquipToolId = "Pickaxe",
		AnimationState = "Mining",
	} :: TRoleStats,
	Brewery = {
		RoleId = "Brewery",
		DisplayName = "Brewer",
		BaseProductionRate = 1.0,
		LevelScaling = 0.1,
		XPPerProduction = 10,
		BasePay = 5,
		CanProduce = false,
		TargetConfig = nil,
	} :: TRoleStats,
	Tailor = {
		RoleId = "Tailor",
		DisplayName = "Tailor",
		BaseProductionRate = 1.0,
		LevelScaling = 0.1,
		XPPerProduction = 10,
		BasePay = 5,
		CanProduce = false,
		TargetConfig = nil,
	} :: TRoleStats,
	Lumberjack = {
		RoleId = "Lumberjack",
		DisplayName = "Lumberjack",
		BaseProductionRate = 1.5,
		LevelScaling = 0.12,
		XPPerProduction = 7,
		BasePay = 4,
		CanProduce = false, -- XP comes from ProcessHarvesting, not the generic production loop
		TargetConfig = TreeConfig,
		EquipToolId = "Axe",
		AnimationState = "Chopping",
	} :: TRoleStats,
	Herbalist = {
		RoleId = "Herbalist",
		DisplayName = "Herbalist",
		BaseProductionRate = 2.0,
		LevelScaling = 0.12,
		XPPerProduction = 6,
		BasePay = 3,
		CanProduce = false, -- XP comes from ProcessHarvesting, not the generic production loop
		TargetConfig = PlantConfig,
	} :: TRoleStats,
	Farmer = {
		RoleId = "Farmer",
		DisplayName = "Farmer",
		BaseProductionRate = 1.0,
		LevelScaling = 0.1,
		XPPerProduction = 8,
		BasePay = 4,
		CanProduce = false, -- XP comes from ProcessHarvesting, not the generic production loop
		TargetConfig = nil, -- Will be set to CropConfig when implemented
	} :: TRoleStats,
} :: { [string]: TRoleStats })
