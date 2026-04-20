--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spec = require(ReplicatedStorage.Utilities.Specification)
local Errors = require(script.Parent.Parent.Parent.Errors)

--[=[
	@class BuildingSpecs
	Defines reusable construction and upgrade eligibility specifications.
	@server
]=]

--[=[
	@interface TConstructCandidate
	@within BuildingSpecs
	.SlotIsEmpty boolean -- True when slot has no existing building.
	.SlotInRange boolean -- True when slot index is within zone limits.
	.BuildingTypeValid boolean -- True when building key exists in zone config.
	.CanAfford boolean -- True when player has sufficient gold.
	.IsUnlocked boolean -- True when unlock requirements are satisfied.
]=]
export type TConstructCandidate = {
	SlotIsEmpty: boolean,
	SlotInRange: boolean,
	BuildingTypeValid: boolean,
	CanAfford: boolean,
	IsUnlocked: boolean,
}

--[=[
	@interface TUpgradeCandidate
	@within BuildingSpecs
	.HasBuilding boolean -- True when slot currently has a building.
	.BelowMaxLevel boolean -- True when current level is below configured max.
]=]
export type TUpgradeCandidate = {
	HasBuilding: boolean,
	BelowMaxLevel: boolean,
}

-- Individual specs (construct)

local SlotIsEmpty = Spec.new("SLOT_OCCUPIED", Errors.SLOT_OCCUPIED,
	function(c: TConstructCandidate) return c.SlotIsEmpty end
)

local SlotInRange = Spec.new("SLOT_OUT_OF_RANGE", Errors.SLOT_OUT_OF_RANGE,
	function(c: TConstructCandidate) return c.SlotInRange end
)

local BuildingTypeValid = Spec.new("UNKNOWN_BUILDING_TYPE", Errors.UNKNOWN_BUILDING_TYPE,
	function(c: TConstructCandidate) return c.BuildingTypeValid end
)

local CanAfford = Spec.new("CANNOT_AFFORD", Errors.CANNOT_AFFORD,
	function(c: TConstructCandidate) return c.CanAfford end
)

local IsUnlocked = Spec.new("BUILDING_LOCKED", Errors.BUILDING_LOCKED,
	function(c: TConstructCandidate) return c.IsUnlocked end
)

-- Individual specs (upgrade)

local HasBuilding = Spec.new("SLOT_EMPTY", Errors.SLOT_EMPTY,
	function(c: TUpgradeCandidate) return c.HasBuilding end
)

local BelowMaxLevel = Spec.new("MAX_LEVEL_REACHED", Errors.MAX_LEVEL_REACHED,
	function(c: TUpgradeCandidate) return c.BelowMaxLevel end
)

--[=[
	@prop CanConstruct any
	@within BuildingSpecs
	Composed specification for construction eligibility.
]=]
--[=[
	@prop CanUpgrade any
	@within BuildingSpecs
	Composed specification for upgrade eligibility.
]=]
return table.freeze({
	CanConstruct = IsUnlocked:And(SlotIsEmpty):And(SlotInRange):And(BuildingTypeValid):And(CanAfford),
	CanUpgrade = HasBuilding:And(BelowMaxLevel),
})
