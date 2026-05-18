--!strict

local Result = require(game:GetService("ReplicatedStorage").Utilities.Result)

local SetupSpecs = require(script.Parent.Parent.Specs.SetupSpecs)

local Ok = Result.Ok

local REQUIRED_OVERRIDE_HOOKS = table.freeze({
	"_ValidateActorTypePayload",
	"_ValidateActorPayload",
	"_BuildStoredActorTypePayload",
	"_BuildRecordFromPayload",
	"_IsRecordActive",
})

local REQUIRED_RUNTIME_METHODS = table.freeze({
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
})

local SetupValidationPolicy = {}

function SetupValidationPolicy.Check(registry: any, baseRegistry: any): any
	local coreStateResult = SetupSpecs.HasCoreState:IsSatisfiedBy({
		Registry = registry,
	})
	if not coreStateResult.success then
		return coreStateResult
	end

	for _, hookName in ipairs(REQUIRED_OVERRIDE_HOOKS) do
		local hookFunctionResult = SetupSpecs.HasHookFunction:IsSatisfiedBy({
			Registry = registry,
			HookName = hookName,
		})
		if not hookFunctionResult.success then
			return Result.Err(hookFunctionResult.type, hookFunctionResult.message .. (" '%s'"):format(hookName))
		end

		local hookResult = SetupSpecs.HasOverriddenHook:IsSatisfiedBy({
			Registry = registry,
			HookName = hookName,
			BaseMethod = baseRegistry[hookName],
		})
		if not hookResult.success then
			return Result.Err(hookResult.type, hookResult.message .. (" '%s'"):format(hookName))
		end
	end

	for _, methodName in ipairs(REQUIRED_RUNTIME_METHODS) do
		local methodResult = SetupSpecs.HasRuntimeMethod:IsSatisfiedBy({
			Registry = registry,
			MethodName = methodName,
		})
		if not methodResult.success then
			return Result.Err(methodResult.type, methodResult.message .. (" '%s'"):format(methodName))
		end
	end

	return Ok(true)
end

return table.freeze(SetupValidationPolicy)
