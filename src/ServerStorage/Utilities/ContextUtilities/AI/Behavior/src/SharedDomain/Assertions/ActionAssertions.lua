--!strict

--[=[
    @class ActionAssertions
    Compatibility assertions that delegate to the shared BehaviorSystem action-validation policy.
    @server
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ActionValidationPolicy = require(script.Parent.Parent.Policies.ActionValidationPolicy)

local Try = Result.Try

local ActionAssertions = {}

function ActionAssertions.AssertExecutor(executor: any, actionId: string)
	Try(ActionValidationPolicy.CheckExecutor(executor, actionId))
end

function ActionAssertions.AssertActionDefinition(definition: any)
	Try(ActionValidationPolicy.CheckActionDefinition(definition))
end

function ActionAssertions.AssertActionState(actionState: any)
	Try(ActionValidationPolicy.CheckActionState(actionState))
end

function ActionAssertions.AssertActionId(actionId: any, label: string)
	Try(ActionValidationPolicy.CheckActionId(actionId, label))
end

return table.freeze(ActionAssertions)
