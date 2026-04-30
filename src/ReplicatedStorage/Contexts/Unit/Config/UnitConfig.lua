--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type UnitDefinition = UnitTypes.UnitDefinition

local UnitConfig = {}

UnitConfig.DEFAULT_UNIT_ID = "AllyGrunt"

UnitConfig.Definitions = {
	AllyGrunt = table.freeze({
		UnitId = "AllyGrunt",
		DisplayName = "Ally Grunt",
		MaxHp = 100,
		ModelScale = Vector3.new(2.5, 5, 1.5),
		ModelColor = Color3.fromRGB(88, 166, 255),
		MaxConcurrentUnitsPerOwner = 5,
	} :: UnitDefinition),
}

return table.freeze(UnitConfig)
