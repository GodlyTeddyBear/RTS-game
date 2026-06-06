--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

for _, definition in Definitions do
	table.freeze(definition.Health)
	table.freeze(definition.AI)
	table.freeze(definition.Movement)
	if definition.Capabilities.Build ~= nil then
		table.freeze(definition.Capabilities.Build)
	end
	table.freeze(definition.Capabilities)
	table.freeze(definition.Limits)
	table.freeze(definition)
end

UnitConfig.Definitions = table.freeze(Definitions)

return table.freeze(UnitConfig)
