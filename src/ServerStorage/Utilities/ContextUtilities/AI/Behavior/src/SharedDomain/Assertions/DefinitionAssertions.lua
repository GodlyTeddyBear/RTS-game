--!strict

--[=[
    @class DefinitionAssertions
    Compatibility assertions that delegate to the shared BehaviorSystem definition-validation policy.
    @server
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local DefinitionValidationPolicy = require(script.Parent.Parent.Policies.DefinitionValidationPolicy)

local Try = Result.Try

local DefinitionAssertions = {}

function DefinitionAssertions.AssertRegistryTable(registry: any, label: string)
	Try(DefinitionValidationPolicy.CheckRegistryTable(registry, label))
end

function DefinitionAssertions.AssertRegistryFunction(name: any, builder: any, label: string)
	Try(DefinitionValidationPolicy.CheckRegistryFunction(name, builder, label))
end

function DefinitionAssertions.AssertNodeShape(node: any, path: string)
	Try(DefinitionValidationPolicy.CheckNodeShape(node, path))
end

function DefinitionAssertions.AssertNonEmptyChildren(children: any, path: string, nodeType: string)
	Try(DefinitionValidationPolicy.CheckNonEmptyChildren(children, path, nodeType))
end

function DefinitionAssertions.AssertKnownLeaf(
	conditions: { [string]: any },
	commands: { [string]: any },
	name: string,
	path: string
)
	Try(DefinitionValidationPolicy.CheckKnownLeaf(conditions, commands, name, path))
end

function DefinitionAssertions.AssertCompositeShape(node: any, path: string)
	Try(DefinitionValidationPolicy.CheckCompositeShape(node, path))
end

function DefinitionAssertions.AssertSequenceNode(node: any, path: string)
	Try(DefinitionValidationPolicy.CheckSequenceNode(node, path))
end

function DefinitionAssertions.AssertPriorityNode(node: any, path: string)
	Try(DefinitionValidationPolicy.CheckPriorityNode(node, path))
end

return table.freeze(DefinitionAssertions)
