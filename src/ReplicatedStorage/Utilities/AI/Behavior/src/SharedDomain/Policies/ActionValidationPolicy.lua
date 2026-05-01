--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local ActionRuntimeShapeSpec = require(script.Parent.Parent.Specs.ActionRuntimeShapeSpec)
local ActionId = require(script.Parent.Parent.ValueObjects.ActionId)

local Ok = Result.Ok
local Try = Result.Try

local ActionValidationPolicy = {}

local function _BuildExecutorError(result: Result.Err, actionId: string): Result.Err
	return Result.Err(result.type, ("BehaviorSystem action '%s' %s"):format(actionId, result.message))
end

local function _BuildActionDefinitionError(result: Result.Err, actionId: string): Result.Err
	return Result.Err(result.type, ("BehaviorSystem action '%s' %s"):format(actionId, result.message))
end

function ActionValidationPolicy.CheckExecutor(executor: any, actionId: string): Result.Result<any>
	local candidate = {
		ActionId = actionId,
		Executor = executor,
	}

	local specResult = ActionRuntimeShapeSpec.HasValidExecutorShape:IsSatisfiedBy(candidate)
	if not specResult.success then
		return _BuildExecutorError(specResult :: Result.Err, actionId)
	end

	return Ok(candidate)
end

function ActionValidationPolicy.CheckActionDefinition(definition: any): Result.Result<any>
	if type(definition) ~= "table" then
		return ActionRuntimeShapeSpec.HasValidActionDefinitionShape:IsSatisfiedBy({
			ActionId = "unknown",
			Definition = definition,
			HasFactory = false,
			HasExecutor = false,
		})
	end

	local actionId = ActionId.From(definition.ActionId, "action definition ActionId")
	local candidate = {
		ActionId = actionId,
		Definition = definition,
		HasFactory = definition.CreateExecutor ~= nil,
		HasExecutor = definition.Executor ~= nil,
	}

	local specResult = ActionRuntimeShapeSpec.HasValidActionDefinitionShape:IsSatisfiedBy(candidate)
	if not specResult.success then
		return _BuildActionDefinitionError(specResult :: Result.Err, actionId)
	end

	if candidate.HasExecutor then
		Try(ActionValidationPolicy.CheckExecutor(definition.Executor, actionId))
	end

	return Ok(candidate)
end

function ActionValidationPolicy.CheckActionState(actionState: any): Result.Result<any>
	return ActionRuntimeShapeSpec.HasValidActionStateShape:IsSatisfiedBy({
		ActionState = actionState,
	})
end

function ActionValidationPolicy.CheckActionId(actionId: any, label: string): Result.Result<string>
	return Ok(ActionId.From(actionId, label))
end

return table.freeze(ActionValidationPolicy)
