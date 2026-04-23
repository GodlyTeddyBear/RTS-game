--!strict

local Validator = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Services.Validator)
local Types = require(script.Parent.Parent.Parent.Parent.Parent.Parent.SharedDomain.Types)

local ValidateDefinition = {}

function ValidateDefinition.ValidateRegistries(config: Types.TBuilderConfig)
	-- Delegate registry validation to the shared domain service so the build use case stays thin
	Validator.ValidateRegistries(config)
end

function ValidateDefinition.Execute(definition: Types.TBehaviorDefinitionNode, config: Types.TBuilderConfig)
	-- Reuse the shared validator so build and runtime paths enforce the same rules
	Validator.ValidateDefinition(definition, config)
end

return table.freeze(ValidateDefinition)
