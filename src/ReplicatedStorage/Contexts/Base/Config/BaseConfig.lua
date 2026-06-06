--!strict

local BaseConfig = {}
local EntityDefinitionTypes = require(script.Parent.Parent.Parent.Entity.Types.EntityDefinitionTypes)
local FreezeDeep = require(script.Parent.Parent.Parent.Parent.Utilities.FreezeDeep)

type BaseDefinition = {
	DefinitionId: string,
	DisplayName: string,
	Health: EntityDefinitionTypes.HealthDefinition,
	Capabilities: EntityDefinitionTypes.EntityCapabilities,
}

local Definitions: { [string]: BaseDefinition } = {
	PrimaryBase = {
		DefinitionId = "PrimaryBase",
		DisplayName = "Primary Base",
		Health = {
			Max = 30000,
		},
		Capabilities = {},
	},
}
BaseConfig.Definitions = FreezeDeep(Definitions)

BaseConfig.REVEAL_NAMESPACE = "Base"
BaseConfig.REVEAL_ENTITY_TYPE = Definitions.PrimaryBase.DefinitionId
BaseConfig.REVEAL_SCOPE_ID = "Global"
BaseConfig.ProductionLayout = {
	SideOffset = 10,
	ForwardStart = -6,
	ForwardSpacing = 4,
	SlotsPerRow = 4,
	RowStep = 4,
}

return FreezeDeep(BaseConfig)
