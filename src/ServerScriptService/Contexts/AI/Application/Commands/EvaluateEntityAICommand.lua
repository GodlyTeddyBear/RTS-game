--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

type TAIEntityEvaluationOptions = AISharedContract.TAIEntityEvaluationOptions
type TAIEntityEvaluationResult = AISharedContract.TAIEntityEvaluationResult

local EvaluateEntityAICommand = {}
EvaluateEntityAICommand.__index = EvaluateEntityAICommand
setmetatable(EvaluateEntityAICommand, BaseCommand)

function EvaluateEntityAICommand.new()
	local self = BaseCommand.new("AI", "EvaluateEntityAI")
	return setmetatable(self, EvaluateEntityAICommand)
end

function EvaluateEntityAICommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_decisionEvaluator", "AIEntityDecisionEvaluator")
end

function EvaluateEntityAICommand:Execute(
	entity: number,
	options: TAIEntityEvaluationOptions?
): Result.Result<TAIEntityEvaluationResult>
	return Result.Catch(function()
		return self._decisionEvaluator:Evaluate(entity, options)
	end, self:_Label())
end

return EvaluateEntityAICommand
