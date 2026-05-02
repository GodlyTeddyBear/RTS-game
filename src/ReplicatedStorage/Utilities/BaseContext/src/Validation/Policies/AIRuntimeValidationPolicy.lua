--!strict

local AIRuntimeContextSpecs = require(script.Parent.Parent.Specs.AIRuntimeContextSpecs)
local ResultAccess = require(script.Parent.Parent.Parent.Internal.ResultAccess)
local ServiceAccess = require(script.Parent.Parent.Parent.Internal.ServiceAccess)

local AIRuntimeValidationPolicy = {}

local function _BuildFailureMessage(prefix: string, result: any): string
	if type(result) == "table" and result.message ~= nil then
		return ("%s: %s"):format(prefix, tostring(result.message))
	end

	return prefix
end

local function _AssertSatisfied(result: any, prefix: string)
	assert(result.success, _BuildFailureMessage(prefix, result))
end

function AIRuntimeValidationPolicy.AssertConfig(service: any, aiRuntimeContext: any?)
	if aiRuntimeContext == nil then
		return
	end

	_AssertSatisfied(
		AIRuntimeContextSpecs.HasValidConfigShape:IsSatisfiedBy({
			AIRuntimeContext = aiRuntimeContext,
		}),
		("%s.AIRuntimeContext is invalid"):format(service.Name)
	)
end

function AIRuntimeValidationPolicy.ValidateRuntime(context: any)
	local service = context._service
	local aiRuntimeContext = service.AIRuntimeContext
	if aiRuntimeContext == nil then
		return
	end

	local runtimeService = ServiceAccess.RequireField(context, aiRuntimeContext.RuntimeServiceField)
	local actorRegistryService = ServiceAccess.RequireField(context, aiRuntimeContext.ActorRegistryServiceField)
	local runtimeCandidate = {
		RuntimeService = runtimeService,
		ActorRegistryService = actorRegistryService,
	}

	_AssertSatisfied(
		AIRuntimeContextSpecs.HasRuntimeServiceValidateSetup:IsSatisfiedBy(runtimeCandidate),
		("%s.AIRuntimeContext runtime service is invalid"):format(service.Name)
	)
	_AssertSatisfied(
		AIRuntimeContextSpecs.HasActorRegistryServiceValidateSetup:IsSatisfiedBy(runtimeCandidate),
		("%s.AIRuntimeContext actor registry service is invalid"):format(service.Name)
	)

	local validateRuntimeSetup = (runtimeService :: any).ValidateSetup
	local validateActorRegistrySetup = (actorRegistryService :: any).ValidateSetup

	ResultAccess.RequireValue(
		validateActorRegistrySetup(actorRegistryService),
		("%s.AIRuntimeContext actor registry setup"):format(service.Name)
	)
	ResultAccess.RequireValue(
		validateRuntimeSetup(runtimeService, actorRegistryService),
		("%s.AIRuntimeContext runtime setup"):format(service.Name)
	)
end

return table.freeze(AIRuntimeValidationPolicy)
