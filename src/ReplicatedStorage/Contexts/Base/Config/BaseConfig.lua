--!strict

local BaseConfig = {}
local EntityDefinitionTypes = require(script.Parent.Parent.Parent.Entity.Types.EntityDefinitionTypes)

type BaseDefinition = {
	DefinitionId: string,
	DisplayName: string,
	Health: EntityDefinitionTypes.HealthDefinition,
	Capabilities: EntityDefinitionTypes.EntityCapabilities,
}

local Definitions: { [string]: BaseDefinition } = table.freeze({
	PrimaryBase = table.freeze({
		DefinitionId = "PrimaryBase",
		DisplayName = "Primary Base",
		Health = table.freeze({
			Max = 30000,
		}),
		Capabilities = table.freeze({}),
	}),
})
BaseConfig.Definitions = Definitions

BaseConfig.REVEAL_NAMESPACE = "Base"
BaseConfig.REVEAL_ENTITY_TYPE = Definitions.PrimaryBase.DefinitionId
BaseConfig.REVEAL_SCOPE_ID = "Global"
BaseConfig.ProductionLayout = table.freeze({
	SideOffset = 10,
	ForwardStart = -6,
	ForwardSpacing = 4,
	SlotsPerRow = 4,
	RowStep = 4,
})

return table.freeze(BaseConfig)
