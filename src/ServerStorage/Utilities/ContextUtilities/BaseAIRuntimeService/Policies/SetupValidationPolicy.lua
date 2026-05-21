--!strict

local Result = require(game:GetService("ReplicatedStorage").Utilities.Result)

local SetupSpecs = require(script.Parent.Parent.Specs.SetupSpecs)

local Ok = Result.Ok

local REQUIRED_ACTOR_REGISTRY_METHODS = table.freeze({
	"IsRuntimeStarted",
	"SetRuntimeStarted",
	"GetActorTypePayloads",
	"GetPendingActorPayloads",
	"RemovePendingActorPayload",
	"RegisterActor",
	"QueueActor",
	"DiscardActor",
	"QueryActiveRuntimeIds",
	"GetCompiledBehaviorTree",
	"GetActionState",
	"SetActionState",
	"ClearActionState",
	"SetPendingAction",
	"UpdateLastTickTime",
	"ShouldEvaluate",
	"CancelActor",
	"ResolveSelectedBatchForTick",
	"GetSelectedRuntimeIdsForActorType",
	"MarkRuntimeIdServiced",
})

local SetupValidationPolicy = {}

function SetupValidationPolicy.Check(runtimeService: any, expectedActorRegistryService: any): any
	local setupCandidate = {
		RuntimeService = runtimeService,
		ExpectedActorRegistryService = expectedActorRegistryService,
	}

	local configResult = SetupSpecs.HasConfigShape:IsSatisfiedBy(setupCandidate)
	if not configResult.success then
		return configResult
	end

	local startupStateResult = SetupSpecs.HasCleanStartupState:IsSatisfiedBy(setupCandidate)
	if not startupStateResult.success then
		if startupStateResult.message == "BaseAIRuntimeService actor registry service does not match expected registry" then
			return Result.Err(
				startupStateResult.type,
				("%s '%s'"):format(startupStateResult.message, runtimeService._actorRegistryServiceName)
			)
		end

		return startupStateResult
	end

	local actorRegistryService = runtimeService._actorRegistryService
	for _, methodName in ipairs(REQUIRED_ACTOR_REGISTRY_METHODS) do
		local methodResult = SetupSpecs.HasRequiredActorRegistryMethod:IsSatisfiedBy({
			ActorRegistryService = actorRegistryService,
			MethodName = methodName,
		})
		if not methodResult.success then
			return Result.Err(methodResult.type, methodResult.message .. (" '%s'"):format(methodName))
		end
	end

	local runtimeStarted = actorRegistryService:IsRuntimeStarted()
	local runtimeFlagResult = SetupSpecs.HasBooleanRuntimeStartedFlag:IsSatisfiedBy({
		RuntimeStarted = runtimeStarted,
	})
	if not runtimeFlagResult.success then
		return runtimeFlagResult
	end

	local stoppedRuntimeResult = SetupSpecs.HasStoppedRuntimeFlag:IsSatisfiedBy({
		RuntimeStarted = runtimeStarted,
	})
	if not stoppedRuntimeResult.success then
		return stoppedRuntimeResult
	end

	return Ok(true)
end

return table.freeze(SetupValidationPolicy)
