--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(ReplicatedStorage.Utilities.AI)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Errors)
local RuntimeBindingSpecs = require(script.Parent.Parent.Specs.RuntimeBindingSpecs)

local Err = Result.Err
local Ok = Result.Ok

local ActorTypeMetadataPolicy = {}

local function _RequiresRuntimeBinding(requirements: any): boolean
	if requirements == nil then
		return false
	end

	return requirements.FactsDependOnPolling == true or requirements.AttributesDependOnProjection == true
end

local function _BuildInvalidPayloadError(actorType: any): Result.Err
	local errorData = nil
	if type(actorType) == "string" and actorType ~= "" then
		errorData = {
			ActorType = actorType,
		}
	end

	return Err("InvalidActorTypePayload", Errors.INVALID_ACTOR_TYPE_PAYLOAD, errorData)
end

local function _CheckRuntimeBindingSpec(spec: any, candidate: any, errorData: { [string]: any }): any
	local result = spec:WithData(errorData):IsSatisfiedBy(candidate)
	if result.success then
		return nil
	end

	return result
end

function ActorTypeMetadataPolicy.Check(payload: any): any
	local requirements = payload.SemanticRequirements
	if requirements ~= nil then
		local didValidateRequirements = pcall(AI.ValidateSemanticRequirements, requirements)
		if not didValidateRequirements then
			return _BuildInvalidPayloadError(payload.ActorType)
		end
	end

	local runtimeBinding = payload.RuntimeBinding
	if runtimeBinding ~= nil then
		local didValidateRuntimeBinding = pcall(AI.ValidateRuntimeBinding, runtimeBinding)
		if not didValidateRuntimeBinding then
			return _BuildInvalidPayloadError(payload.ActorType)
		end
	end

	if not _RequiresRuntimeBinding(requirements) then
		return Ok(nil)
	end

	if runtimeBinding == nil then
		return Err("MissingActorRuntimeBinding", Errors.MISSING_ACTOR_RUNTIME_BINDING, {
			ActorType = payload.ActorType,
		})
	end

	local runtimeOwner = payload.RuntimeOwner
	local getStatus = if type(runtimeOwner) == "table" then runtimeOwner.GetSchedulerBindingStatus else nil
	if type(getStatus) ~= "function" then
		return Err("InvalidActorRuntimeBindingOwner", Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
		})
	end

	local statusResult = getStatus(runtimeOwner, runtimeBinding.ServiceField)
	if type(statusResult) ~= "table" or statusResult.success ~= true then
		return Err("InvalidActorRuntimeBindingOwner", Errors.INVALID_ACTOR_RUNTIME_BINDING_OWNER, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			CauseType = if type(statusResult) == "table" then statusResult.type else "MissingResult",
			CauseMessage = if type(statusResult) == "table"
				then statusResult.message
				else "Runtime owner did not return a successful scheduler binding Result",
		})
	end

	local candidate = {
		RuntimeBinding = runtimeBinding,
		BindingStatus = statusResult.value,
	}

	local targetResult = _CheckRuntimeBindingSpec(RuntimeBindingSpecs.HasRuntimeTarget, candidate, {
		ActorType = payload.ActorType,
		ServiceField = runtimeBinding.ServiceField,
		CauseMessage = "Runtime owner did not expose the bound service field",
	})
	if targetResult ~= nil then
		return targetResult
	end

	if requirements.FactsDependOnPolling == true then
		local pollMethodResult = _CheckRuntimeBindingSpec(RuntimeBindingSpecs.HasPollMethod, candidate, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			ExpectedMethod = "Poll",
			MissingRequirement = "FactsDependOnPolling",
		})
		if pollMethodResult ~= nil then
			return pollMethodResult
		end

		local pollPhaseResult = _CheckRuntimeBindingSpec(RuntimeBindingSpecs.HasPollPhase, candidate, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			ExpectedMethod = "Poll",
			ExpectedPhase = runtimeBinding.PollPhase,
			MissingRequirement = "FactsDependOnPolling",
		})
		if pollPhaseResult ~= nil then
			return pollPhaseResult
		end
	end

	if requirements.AttributesDependOnProjection == true then
		local syncMethodResult = _CheckRuntimeBindingSpec(RuntimeBindingSpecs.HasSyncMethod, candidate, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			ExpectedMethod = "SyncDirtyEntities",
			MissingRequirement = "AttributesDependOnProjection",
		})
		if syncMethodResult ~= nil then
			return syncMethodResult
		end

		local syncPhaseResult = _CheckRuntimeBindingSpec(RuntimeBindingSpecs.HasSyncPhase, candidate, {
			ActorType = payload.ActorType,
			ServiceField = runtimeBinding.ServiceField,
			ExpectedMethod = "SyncDirtyEntities",
			ExpectedPhase = runtimeBinding.SyncPhase,
			MissingRequirement = "AttributesDependOnProjection",
		})
		if syncPhaseResult ~= nil then
			return syncPhaseResult
		end
	end

	return Ok(candidate)
end

return table.freeze(ActorTypeMetadataPolicy)
