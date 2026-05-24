--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type UnitDefinition = UnitTypes.UnitDefinition

local UnitConfig = {}

UnitConfig.DEFAULT_UNIT_ID = "AllyGrunt"

UnitConfig.Definitions = {
	AllyGrunt = table.freeze({
		UnitId = "AllyGrunt",
		RuntimeProfileId = "Idle",
		Role = "Combat",
		DisplayName = "Ally Grunt",
		MaxHp = 100,
		MoveSpeed = 16,
		ModelScale = Vector3.new(2.5, 5, 1.5),
		ModelColor = Color3.fromRGB(88, 166, 255),
		MaxConcurrentUnitsPerOwner = 5,
	} :: UnitDefinition),
	Builder = table.freeze({
		UnitId = "Builder",
		RuntimeProfileId = "Builder",
		Role = "Builder",
		DisplayName = "Builder",
		MaxHp = 140,
		MoveSpeed = 14,
		ModelScale = Vector3.new(3, 5, 2),
		ModelColor = Color3.fromRGB(255, 196, 92),
		MaxConcurrentUnitsPerOwner = 3,
	} :: UnitDefinition),
}

return table.freeze(UnitConfig)
