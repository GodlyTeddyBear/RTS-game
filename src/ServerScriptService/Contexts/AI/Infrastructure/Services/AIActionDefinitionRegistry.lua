--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TActionDefinitionPayload = {
	ActionId: string,
	ProduceIntent: (...any) -> any,
	StartsComponent: AISharedContract.TAIActionStartComponent?,
	BuildInitialState: ((context: AISharedContract.TAIActionStartContext) -> any)?,
	CanStart: ((context: AISharedContract.TAIActionStartContext) -> any)?,
	Metadata: any?,
}

local AIActionDefinitionRegistry = {}
AIActionDefinitionRegistry.__index = AIActionDefinitionRegistry

function AIActionDefinitionRegistry.new()
	local self = setmetatable({}, AIActionDefinitionRegistry)
	self._actionsById = {}
	return self
end

function AIActionDefinitionRegistry:Init(_registry: any, _name: string)
end

function AIActionDefinitionRegistry:RegisterActionDefinition(payload: TActionDefinitionPayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		self._actionsById[payload.ActionId] = table.freeze({
			ActionId = payload.ActionId,
			ProduceIntent = payload.ProduceIntent,
			StartsComponent = self:_CloneStartComponent(payload.StartsComponent),
			BuildInitialState = payload.BuildInitialState,
			CanStart = payload.CanStart,
			Metadata = payload.Metadata,
		})
		return Result.Ok(true)
	end, "AIActionDefinitionRegistry:RegisterActionDefinition")
end

function AIActionDefinitionRegistry:GetActionDefinition(actionId: string): any?
	return self._actionsById[actionId]
end

function AIActionDefinitionRegistry:GetStatus(): any
	return table.freeze({
		ActionCount = self:_CountActions(),
	})
end

function AIActionDefinitionRegistry:_ValidatePayload(payload: TActionDefinitionPayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.ActionId) ~= "string" or payload.ActionId == "" then
		return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
			Reason = "MissingActionId",
		})
	end
	if type(payload.ProduceIntent) ~= "function" then
		return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
			ActionId = payload.ActionId,
			Reason = "MissingProduceIntentCallback",
		})
	end
	local orchestrationResult = self:_ValidateOrchestrationPayload(payload)
	if not orchestrationResult.success then
		return orchestrationResult
	end
	if self._actionsById[payload.ActionId] ~= nil then
		return Result.Err("DuplicateActionDefinition", Errors.DUPLICATE_ACTION_DEFINITION, {
			ActionId = payload.ActionId,
		})
	end

	return Result.Ok(true)
end

function AIActionDefinitionRegistry:_ValidateOrchestrationPayload(payload: TActionDefinitionPayload): Result.Result<boolean>
	local hasStartComponent = payload.StartsComponent ~= nil
	local hasBuildInitialState = payload.BuildInitialState ~= nil

	if hasStartComponent ~= hasBuildInitialState then
		return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
			ActionId = payload.ActionId,
			Reason = "IncompleteActionOrchestrationContract",
		})
	end

	if hasStartComponent then
		local startsComponent = payload.StartsComponent
		if
			type(startsComponent) ~= "table"
			or type(startsComponent.FeatureName) ~= "string"
			or startsComponent.FeatureName == ""
			or type(startsComponent.Key) ~= "string"
			or startsComponent.Key == ""
		then
			return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
				ActionId = payload.ActionId,
				Reason = "InvalidStartsComponent",
			})
		end
	end

	if hasBuildInitialState and type(payload.BuildInitialState) ~= "function" then
		return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
			ActionId = payload.ActionId,
			Reason = "InvalidBuildInitialStateCallback",
		})
	end

	if payload.CanStart ~= nil and type(payload.CanStart) ~= "function" then
		return Result.Err("InvalidActionDefinition", Errors.INVALID_ACTION_DEFINITION, {
			ActionId = payload.ActionId,
			Reason = "InvalidCanStartCallback",
		})
	end

	return Result.Ok(true)
end

function AIActionDefinitionRegistry:_CloneStartComponent(startsComponent: AISharedContract.TAIActionStartComponent?): any
	if startsComponent == nil then
		return nil
	end

	return table.freeze({
		FeatureName = startsComponent.FeatureName,
		Key = startsComponent.Key,
	})
end

function AIActionDefinitionRegistry:_CountActions(): number
	local count = 0
	for _ in pairs(self._actionsById) do
		count += 1
	end
	return count
end

return AIActionDefinitionRegistry
