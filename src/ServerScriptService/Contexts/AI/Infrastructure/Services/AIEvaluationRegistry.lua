--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TEvaluationPayload = {
	EvaluationId: string,
	Evaluate: (...any) -> any,
	Metadata: any?,
}

local AIEvaluationRegistry = {}
AIEvaluationRegistry.__index = AIEvaluationRegistry

function AIEvaluationRegistry.new()
	local self = setmetatable({}, AIEvaluationRegistry)
	self._evaluationsById = {}
	return self
end

function AIEvaluationRegistry:Init(_registry: any, _name: string)
end

function AIEvaluationRegistry:RegisterEvaluation(payload: TEvaluationPayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		self._evaluationsById[payload.EvaluationId] = table.freeze({
			EvaluationId = payload.EvaluationId,
			Evaluate = payload.Evaluate,
			Metadata = payload.Metadata,
		})
		return Result.Ok(true)
	end, "AIEvaluationRegistry:RegisterEvaluation")
end

function AIEvaluationRegistry:GetEvaluation(evaluationId: string): any?
	return self._evaluationsById[evaluationId]
end

function AIEvaluationRegistry:GetStatus(): any
	return table.freeze({
		EvaluationCount = self:_CountEvaluations(),
	})
end

function AIEvaluationRegistry:_ValidatePayload(payload: TEvaluationPayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.EvaluationId) ~= "string" or payload.EvaluationId == "" then
		return Result.Err("InvalidEvaluation", Errors.INVALID_EVALUATION, {
			Reason = "MissingEvaluationId",
		})
	end
	if type(payload.Evaluate) ~= "function" then
		return Result.Err("InvalidEvaluation", Errors.INVALID_EVALUATION, {
			EvaluationId = payload.EvaluationId,
			Reason = "MissingEvaluateCallback",
		})
	end
	if self._evaluationsById[payload.EvaluationId] ~= nil then
		return Result.Err("DuplicateEvaluation", Errors.DUPLICATE_EVALUATION, {
			EvaluationId = payload.EvaluationId,
		})
	end

	return Result.Ok(true)
end

function AIEvaluationRegistry:_CountEvaluations(): number
	local count = 0
	for _ in pairs(self._evaluationsById) do
		count += 1
	end
	return count
end

return AIEvaluationRegistry
