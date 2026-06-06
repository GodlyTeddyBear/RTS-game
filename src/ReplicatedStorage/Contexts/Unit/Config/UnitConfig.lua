--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreezeDeep = require(ReplicatedStorage.Utilities.FreezeDeep)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

type UnitDefinition = UnitTypes.UnitDefinition

local UnitConfig = {}

UnitConfig.DEFAULT_UNIT_ID = "AllyGrunt"

local Definitions: { [string]: UnitDefinition } = {
	AllyGrunt = {
		DefinitionId = "AllyGrunt",
		Role = "Combat",
		DisplayName = "Ally Grunt",
		Health = { Max = 100 },
		AI = { ProfileId = "UnitBuilderAI", TickInterval = 0.15 },
		Movement = { Mode = "Path", Speed = 16 },
		Capabilities = {},
		Limits = { MaxConcurrentPerOwner = 5 },
	},
	Builder = {
		DefinitionId = "Builder",
		Role = "Builder",
		DisplayName = "Builder",
		Health = { Max = 140 },
		AI = { ProfileId = "UnitBuilderAI", TickInterval = 0.15 },
		Movement = { Mode = "Path", Speed = 14 },
		Capabilities = {
			Build = {
				WorkPerSecond = 10,
				Range = 12,
			},
		},
		Limits = { MaxConcurrentPerOwner = 3 },
	},
}

UnitConfig.Definitions = FreezeDeep(Definitions)

return FreezeDeep(UnitConfig)
