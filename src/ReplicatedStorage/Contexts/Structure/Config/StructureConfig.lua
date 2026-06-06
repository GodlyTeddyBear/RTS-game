--!strict

--[=[
	@class StructureConfig
	Defines shared structure metadata and aliases used by placement and combat.
	@server
	@client
]=]
local StructureConfig = {}
local StructureTypes = require(script.Parent.Parent.Types.StructureTypes)

type TStructureConfig = StructureTypes.TStructureConfig

--[=[
	@prop Definitions { [string]: TStructureConfig }
	@within StructureConfig
	Frozen structure definitions keyed by canonical structure type.
]=]
local Definitions: { [string]: TStructureConfig } = {
	SentryTurret = {
		DefinitionId = "SentryTurret",
		DisplayName = "Sentry Turret",
		Health = { Max = 100 },
		AI = { ProfileId = "StructureAttackAI" },
		Capabilities = {
			Attack = {
				Damage = 15,
				Range = 90,
				Cooldown = 1.2,
			},
			Construction = { RequiredWork = 100 },
			Aim = {
				Strategy = "IKControl",
				ChainRootPath = "Neck",
				EndEffectorPath = "Body",
				SmoothTime = 0.15,
				Weight = 1,
				Priority = 1,
				ReturnToNeutralWhenNoTarget = false,
			},
		},
	},
	Extractor = {
		DefinitionId = "Extractor",
		DisplayName = "Extractor",
		Health = { Max = 140 },
		AI = { ProfileId = "StructureExtractAI" },
		Capabilities = {
			Construction = { RequiredWork = 100 },
		},
	},
	StasisField = {
		DefinitionId = "StasisField",
		DisplayName = "Stasis Field",
		Health = { Max = 140 },
		AI = { ProfileId = "StructureStasisAI" },
		Capabilities = {
			Construction = { RequiredWork = 100 },
			StatusAura = {
				Radius = 18,
				MoveSpeedMultiplier = 0.5,
			},
		},
	},
	ArcPylon = {
		DefinitionId = "ArcPylon",
		DisplayName = "Arc Pylon",
		Health = { Max = 140 },
		AI = { ProfileId = "StructurePassiveAI" },
		Capabilities = {
			Construction = { RequiredWork = 100 },
		},
	},
	BulwarkProjector = {
		DefinitionId = "BulwarkProjector",
		DisplayName = "Bulwark Projector",
		Health = { Max = 140 },
		AI = { ProfileId = "StructurePassiveAI" },
		Capabilities = {
			Construction = { RequiredWork = 100 },
		},
	},
	RelayBeacon = {
		DefinitionId = "RelayBeacon",
		DisplayName = "Relay Beacon",
		Health = { Max = 140 },
		AI = { ProfileId = "StructurePassiveAI" },
		Capabilities = {
			Construction = { RequiredWork = 100 },
		},
	},
}

for _, definition in Definitions do
	table.freeze(definition.Health)
	table.freeze(definition.AI)
	if definition.Capabilities.Attack ~= nil then
		table.freeze(definition.Capabilities.Attack)
	end
	table.freeze(definition.Capabilities.Construction)
	if definition.Capabilities.StatusAura ~= nil then
		table.freeze(definition.Capabilities.StatusAura)
	end
	if type(definition.Capabilities.Aim) == "table" then
		table.freeze(definition.Capabilities.Aim)
	end
	table.freeze(definition.Capabilities)
	table.freeze(definition)
end

StructureConfig.Definitions = table.freeze(Definitions)

--[=[
	@prop TYPE_ALIASES { [string]: string }
	@within StructureConfig
	Frozen aliases that normalize legacy placement keys to canonical structure types.
]=]
StructureConfig.TYPE_ALIASES = table.freeze({
	SentryTurret = "SentryTurret",
	turret = "SentryTurret",
	Extractor = "Extractor",
	StasisField = "StasisField",
	ArcPylon = "ArcPylon",
	["Arc Pylon"] = "ArcPylon",
	BulwarkProjector = "BulwarkProjector",
	["Bulwark Projector"] = "BulwarkProjector",
	RelayBeacon = "RelayBeacon",
	["Relay Beacon"] = "RelayBeacon",
})

return table.freeze(StructureConfig)
