--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityLifecyclePolicy = {}
EntityLifecyclePolicy.__index = EntityLifecyclePolicy

function EntityLifecyclePolicy.new()
	return setmetatable({}, EntityLifecyclePolicy)
end

function EntityLifecyclePolicy:Init(_registry: any, _name: string)
	return
end

function EntityLifecyclePolicy:RequireStates(
	validationService: any,
	methodName: string,
	currentState: string,
	expectedStates: { string }
): Result.Result<boolean>
	return validationService:ValidateLifecycleExpectation(methodName, currentState, expectedStates)
end

function EntityLifecyclePolicy:ValidateKernelReady(schemaRegistry: any, systemRegistry: any): Result.Err?
	local schemaResult = schemaRegistry:ValidateReady()
	if not schemaResult.success then
		return schemaResult
	end

	local systemResult = systemRegistry:ValidateReady()
	if not systemResult.success then
		return systemResult
	end

	return nil
end

function EntityLifecyclePolicy:ValidateRuntimeBridgeReady(
	instanceBindingRegistry: any,
	syncContributorRegistry: any,
	replicationRegistry: any
): Result.Err?
	local bindingResult = instanceBindingRegistry:ValidateReady()
	if not bindingResult.success then
		return bindingResult
	end

	local syncContributorResult = syncContributorRegistry:ValidateReady()
	if not syncContributorResult.success then
		return syncContributorResult
	end

	local replicationResult = replicationRegistry:ValidateReady()
	if not replicationResult.success then
		return replicationResult
	end

	return nil
end

function EntityLifecyclePolicy:ValidateAIReady(aiActorTypeRegistry: any, combatAIRuntimeBridge: any): Result.Err?
	local actorTypeStatus = aiActorTypeRegistry:GetStatus()
	if actorTypeStatus.ActorTypeCount <= 0 then
		return Result.Err("MissingRequiredAIActorType", Errors.MISSING_REQUIRED_AI_ACTOR_TYPE, {
			ActorTypeCount = actorTypeStatus.ActorTypeCount,
		})
	end

	local actorTypeRegistryResult = aiActorTypeRegistry:ValidateReady()
	if not actorTypeRegistryResult.success then
		return actorTypeRegistryResult
	end

	local aiBridgeResult = combatAIRuntimeBridge:ValidateReady()
	if not aiBridgeResult.success then
		return aiBridgeResult
	end

	return nil
end

return EntityLifecyclePolicy
