--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local RegisterEvaluationCommand = {}
RegisterEvaluationCommand.__index = RegisterEvaluationCommand
setmetatable(RegisterEvaluationCommand, BaseCommand)

function RegisterEvaluationCommand.new()
	local self = BaseCommand.new("AI", "RegisterEvaluation")
	return setmetatable(self, RegisterEvaluationCommand)
end

function RegisterEvaluationCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_evaluationRegistry", "AIEvaluationRegistry")
end

function RegisterEvaluationCommand:Execute(payload: any): Result.Result<boolean>
	return Result.Catch(function()
		return self._evaluationRegistry:RegisterEvaluation(payload)
	end, self:_Label())
end

return RegisterEvaluationCommand
