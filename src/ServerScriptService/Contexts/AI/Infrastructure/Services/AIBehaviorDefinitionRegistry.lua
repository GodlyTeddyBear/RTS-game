--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TBehaviorDefinitionPayload = {
	DefinitionId: string,
	Definition: any,
	Metadata: any?,
}

local AIBehaviorDefinitionRegistry = {}
AIBehaviorDefinitionRegistry.__index = AIBehaviorDefinitionRegistry

function AIBehaviorDefinitionRegistry.new()
	local self = setmetatable({}, AIBehaviorDefinitionRegistry)
	self._definitionsById = {}
	return self
end

function AIBehaviorDefinitionRegistry:Init(_registry: any, _name: string)
	self._definitionPolicy = _registry:Get("AIBehaviorDefinitionPolicy")
	self._definitionCompiler = _registry:Get("AIBehaviorDefinitionCompiler")
end

function AIBehaviorDefinitionRegistry:RegisterDefinition(payload: TBehaviorDefinitionPayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		local compileResult = self._definitionCompiler:Compile(payload.Definition)
		if not compileResult.success then
			return self._definitionCompiler:BuildCompilationFailure(payload.DefinitionId, compileResult)
		end

		self._definitionsById[payload.DefinitionId] = table.freeze({
			DefinitionId = payload.DefinitionId,
			Definition = self:_CloneAndFreeze(payload.Definition),
			CompiledTree = compileResult.value,
			Metadata = self:_CloneAndFreeze(payload.Metadata),
		})
		return Result.Ok(true)
	end, "AIBehaviorDefinitionRegistry:RegisterDefinition")
end

function AIBehaviorDefinitionRegistry:GetDefinition(definitionId: string): any?
	return self._definitionsById[definitionId]
end

function AIBehaviorDefinitionRegistry:GetStatus(): any
	return table.freeze({
		DefinitionCount = self:_CountDefinitions(),
	})
end

function AIBehaviorDefinitionRegistry:_ValidatePayload(payload: TBehaviorDefinitionPayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.DefinitionId) ~= "string" or payload.DefinitionId == "" then
		return Result.Err("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, {
			Reason = "MissingDefinitionId",
		})
	end
	if payload.Definition == nil then
		return Result.Err("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, {
			DefinitionId = payload.DefinitionId,
			Reason = "MissingDefinition",
		})
	end
	if self._definitionsById[payload.DefinitionId] ~= nil then
		return Result.Err("DuplicateBehaviorDefinition", Errors.DUPLICATE_BEHAVIOR_DEFINITION, {
			DefinitionId = payload.DefinitionId,
		})
	end
	if self._definitionPolicy == nil then
		return Result.Err("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, {
			DefinitionId = payload.DefinitionId,
			Reason = "RegistryNotInitialized",
		})
	end
	if self._definitionCompiler == nil then
		return Result.Err("InvalidBehaviorDefinition", Errors.INVALID_BEHAVIOR_DEFINITION, {
			DefinitionId = payload.DefinitionId,
			Reason = "CompilerNotInitialized",
		})
	end

	local definitionResult = self._definitionPolicy:Check(payload.Definition)
	if not definitionResult.success then
		return definitionResult
	end

	return Result.Ok(true)
end

function AIBehaviorDefinitionRegistry:_CloneAndFreeze(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_CloneAndFreeze(nestedValue)
	end

	return table.freeze(clone)
end

function AIBehaviorDefinitionRegistry:_CountDefinitions(): number
	local count = 0
	for _ in pairs(self._definitionsById) do
		count += 1
	end
	return count
end

return AIBehaviorDefinitionRegistry
