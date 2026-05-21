--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

local function _ContainsPhase(registeredPhases: { string }, expectedPhase: string?): boolean
	if expectedPhase == nil then
		return #registeredPhases > 0
	end

	for _, registeredPhase in ipairs(registeredPhases) do
		if registeredPhase == expectedPhase then
			return true
		end
	end

	return false
end

local function _IsMethodNameOrCallback(value: any): boolean
	local valueType = type(value)
	return valueType == "string" or valueType == "function"
end

local HasActorType = Spec.new("InvalidActorType", "AI actorType must be a non-empty string", function(candidate): boolean
	local actorType = candidate.ActorType
	return type(actorType) == "string" and #actorType > 0
end)

local HasArchetypeName = Spec.new("InvalidArchetypeName", "AI archetype name must be a non-empty string", function(candidate): boolean
	local archetypeName = candidate.ArchetypeName
	return type(archetypeName) == "string" and #archetypeName > 0
end)

local HasAdapterTable = Spec.new("InvalidActorAdapter", "AI adapter must be a table", function(candidate): boolean
	return type(candidate.Adapter) == "table"
end)

local HasRegistrationTable = Spec.new("InvalidActorRegistration", "AI actor registration must be a table", function(candidate): boolean
	return type(candidate.Registration) == "table"
end)

local HasSemanticRequirementsTable = Spec.new(
	"InvalidSemanticRequirements",
	"AI semantic requirements must be a table",
	function(candidate): boolean
		return type(candidate.Requirements) == "table"
	end
)

local HasFactsDependOnPollingBooleanOrNil = Spec.new(
	"InvalidSemanticRequirements",
	"AI semantic requirements FactsDependOnPolling must be a boolean",
	function(candidate): boolean
		local requirements = candidate.Requirements
		if type(requirements) ~= "table" then
			return true
		end

		local value = requirements.FactsDependOnPolling
		return value == nil or type(value) == "boolean"
	end
)

local HasAttributesDependOnProjectionBooleanOrNil = Spec.new(
	"InvalidSemanticRequirements",
	"AI semantic requirements AttributesDependOnProjection must be a boolean",
	function(candidate): boolean
		local requirements = candidate.Requirements
		if type(requirements) ~= "table" then
			return true
		end

		local value = requirements.AttributesDependOnProjection
		return value == nil or type(value) == "boolean"
	end
)

local HasRuntimeBindingTable = Spec.new("InvalidRuntimeBinding", "AI runtime binding must be a table", function(candidate): boolean
	return type(candidate.RuntimeBinding) == "table"
end)

local HasServiceField = Spec.new(
	"InvalidRuntimeBinding",
	"AI runtime binding ServiceField must be a non-empty string",
	function(candidate): boolean
		local runtimeBinding = candidate.RuntimeBinding
		return type(runtimeBinding) ~= "table"
			or (type(runtimeBinding.ServiceField) == "string" and #runtimeBinding.ServiceField > 0)
	end
)

local HasPollPhaseStringOrNil = Spec.new(
	"InvalidRuntimeBinding",
	"AI runtime binding PollPhase must be a non-empty string",
	function(candidate): boolean
		local runtimeBinding = candidate.RuntimeBinding
		if type(runtimeBinding) ~= "table" then
			return true
		end

		local pollPhase = runtimeBinding.PollPhase
		return pollPhase == nil or (type(pollPhase) == "string" and #pollPhase > 0)
	end
)

local HasSyncPhaseStringOrNil = Spec.new(
	"InvalidRuntimeBinding",
	"AI runtime binding SyncPhase must be a non-empty string",
	function(candidate): boolean
		local runtimeBinding = candidate.RuntimeBinding
		if type(runtimeBinding) ~= "table" then
			return true
		end

		local syncPhase = runtimeBinding.SyncPhase
		return syncPhase == nil or (type(syncPhase) == "string" and #syncPhase > 0)
	end
)

local HasRegistrationOptionsTable = Spec.new(
	"InvalidRegistrationOptions",
	"AI registration validation options must be a table",
	function(candidate): boolean
		return type(candidate.Options) == "table"
	end
)

local HasRuntimeOwnerTableOrNil = Spec.new(
	"InvalidRegistrationOptions",
	"AI registration validation RuntimeOwner must be a table",
	function(candidate): boolean
		local options = candidate.Options
		if type(options) ~= "table" then
			return true
		end

		local runtimeOwner = options.RuntimeOwner
		return runtimeOwner == nil or type(runtimeOwner) == "table"
	end
)

local HasRuntimeOwnerGetSchedulerBindingStatus = Spec.new(
	"InvalidRegistrationOptions",
	"AI registration validation RuntimeOwner must expose GetSchedulerBindingStatus",
	function(candidate): boolean
		local options = candidate.Options
		if type(options) ~= "table" then
			return true
		end

		local runtimeOwner = options.RuntimeOwner
		return runtimeOwner == nil or type((runtimeOwner :: any).GetSchedulerBindingStatus) == "function"
	end
)

local HasHooksTable = Spec.new("InvalidHooks", "AI hooks must be an array", function(candidate): boolean
	return type(candidate.Hooks) == "table"
end)

local HasActionDefinitionsTable = Spec.new(
	"InvalidActionDefinitions",
	"AI action definitions must be a table",
	function(candidate): boolean
		return type(candidate.ActionDefinitions) == "table"
	end
)

local HasActionPackTable = Spec.new("InvalidActionPack", "AI action pack must be a table", function(candidate): boolean
	return type(candidate.ActionPack) == "table"
end)

local HasActionPackName = Spec.new(
	"InvalidActionPack",
	"AI action pack name must be a non-empty string",
	function(candidate): boolean
		local actionPack = candidate.ActionPack
		return type(actionPack) ~= "table" or (type(actionPack.Name) == "string" and #actionPack.Name > 0)
	end
)

local HasBehaviorRegistrationName = Spec.new(
	"InvalidBehaviorRegistrationName",
	"AI behavior registration name must be a non-empty string",
	function(candidate): boolean
		local name = candidate.Name
		return type(name) == "string" and #name > 0
	end
)

local HasNonNegativeTickInterval = Spec.new(
	"InvalidTickInterval",
	"AI tick interval must be a non-negative number",
	function(candidate): boolean
		local tickInterval = candidate.TickInterval
		return type(tickInterval) == "number" and tickInterval >= 0
	end
)

local HasBehaviorRegistrationTable = Spec.new(
	"InvalidBehaviorRegistration",
	"AI behavior registration must be a table",
	function(candidate): boolean
		return type(candidate.Registration) == "table"
	end
)

local HasAssignmentRequestTable = Spec.new(
	"InvalidAssignmentRequest",
	"AI assignment request must be a table",
	function(candidate): boolean
		return type(candidate.Request) == "table"
	end
)

local HasActorSetupRequestTable = Spec.new(
	"InvalidActorSetupRequest",
	"AI actor setup request must be a table",
	function(candidate): boolean
		return type(candidate.Request) == "table"
	end
)

local HasActorSetupRequestEntity = Spec.new(
	"InvalidActorSetupRequest",
	"AI actor setup request.Entity must be a number",
	function(candidate): boolean
		local request = candidate.Request
		return type(request) ~= "table" or type(request.Entity) == "number"
	end
)

local HasActorSetupResultTable = Spec.new(
	"InvalidActorSetupResult",
	"AI actor setup result must be a table",
	function(candidate): boolean
		return type(candidate.SetupResult) == "table"
	end
)

local HasActorSetupResultEntity = Spec.new(
	"InvalidActorSetupResult",
	"AI actor setup result.Entity must be a number",
	function(candidate): boolean
		local setupResult = candidate.SetupResult
		return type(setupResult) ~= "table" or type(setupResult.Entity) == "number"
	end
)

local HasActorSetupResultFoundBoolean = Spec.new(
	"InvalidActorSetupResult",
	"AI actor setup result.Found must be a boolean",
	function(candidate): boolean
		local setupResult = candidate.SetupResult
		return type(setupResult) ~= "table" or type(setupResult.Found) == "boolean"
	end
)

local HasActorSetupWriteConfigTable = Spec.new(
	"InvalidActorSetupWriteConfig",
	"AI actor setup write config must be a table",
	function(candidate): boolean
		return type(candidate.Config) == "table"
	end
)

local HasActorSetupWriteFunction = Spec.new(
	"InvalidActorSetupWriteConfig",
	"AI actor setup write config.WriteSetup must be a function",
	function(candidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.WriteSetup) == "function"
	end
)

local HasFactorySetupWriteConfigTable = Spec.new(
	"InvalidFactorySetupWriteConfig",
	"AI factory setup write config must be a table",
	function(candidate): boolean
		return type(candidate.Config) == "table"
	end
)

local HasFactorySetupFactory = Spec.new(
	"InvalidFactorySetupWriteConfig",
	"AI factory setup write config.Factory is required",
	function(candidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or config.Factory ~= nil
	end
)

local HasFactorySetupWriteSurface = Spec.new(
	"InvalidFactorySetupWriteConfig",
	"AI factory setup write config.WriteSetup must be a method-name string or function",
	function(candidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or _IsMethodNameOrCallback(config.WriteSetup)
	end
)

local HasBehaviorCatalogConfigTable = Spec.new(
	"InvalidBehaviorCatalogConfig",
	"AI behavior catalog config must be a table",
	function(candidate): boolean
		return type(candidate.Config) == "table"
	end
)

local HasFolderInstance = Spec.new("InvalidRegistrationFolder", "AI folder must be an Instance", function(candidate): boolean
	return typeof(candidate.Folder) == "Instance"
end)

local HasSystemConfigTable = Spec.new("InvalidSystemConfig", "AI system config must be a table", function(candidate): boolean
	return type(candidate.Config) == "table"
end)

local HasSystemConditionsTable = Spec.new(
	"InvalidSystemConfig",
	"AI system config.Conditions must be a table",
	function(candidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.Conditions) == "table"
	end
)

local HasSystemCommandsTable = Spec.new(
	"InvalidSystemConfig",
	"AI system config.Commands must be a table",
	function(candidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.Commands) == "table"
	end
)

local HasSystemErrorSinkFunctionOrNil = Spec.new(
	"InvalidSystemConfig",
	"AI system config.ErrorSink must be a function",
	function(candidate): boolean
		local config = candidate.Config
		if type(config) ~= "table" then
			return true
		end

		local errorSink = config.ErrorSink
		return errorSink == nil or type(errorSink) == "function"
	end
)

local HasRuntimeTable = Spec.new("InvalidRuntime", "AI runtime must be a table", function(candidate): boolean
	return type(candidate.Runtime) == "table"
end)

local HasRuntimeRegisterActorType = Spec.new(
	"InvalidRuntime",
	"AI runtime must expose RegisterActorType",
	function(candidate): boolean
		local runtime = candidate.Runtime
		return type(runtime) ~= "table" or type((runtime :: any).RegisterActorType) == "function"
	end
)

local HasRuntimeRegisterActions = Spec.new(
	"InvalidRuntime",
	"AI runtime must expose RegisterActions",
	function(candidate): boolean
		local runtime = candidate.Runtime
		return type(runtime) ~= "table" or type((runtime :: any).RegisterActions) == "function"
	end
)

local HasRuntimeBuildTree = Spec.new("InvalidRuntime", "AI runtime must expose BuildTree", function(candidate): boolean
	local runtime = candidate.Runtime
	return type(runtime) ~= "table" or type((runtime :: any).BuildTree) == "function"
end)

local HasBindingResultTable = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI runtime owner must return a Result-like table",
	function(candidate): boolean
		return type(candidate.BindingResult) == "table"
	end
)

local HasSuccessfulBindingResult = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI runtime owner failed to resolve the requested binding",
	function(candidate): boolean
		local bindingResult = candidate.BindingResult
		return type(bindingResult) == "table" and bindingResult.success == true
	end
)

local HasBindingStatusTable = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI binding status must be a table",
	function(candidate): boolean
		local bindingResult = candidate.BindingResult
		return type(bindingResult) ~= "table" or type(bindingResult.value) == "table"
	end
)

local HasBindingTarget = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI bound service field does not exist",
	function(candidate): boolean
		local bindingStatus = candidate.BindingStatus
		return type(bindingStatus) == "table" and bindingStatus.TargetExists == true
	end
)

local HasBindingPollMethod = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI bound service field is missing Poll",
	function(candidate): boolean
		local bindingStatus = candidate.BindingStatus
		local pollStatus = if type(bindingStatus) == "table" then bindingStatus.Poll else nil
		return type(pollStatus) == "table" and pollStatus.HasMethod == true
	end
)

local HasBindingPollPhase = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI bound service field Poll is not registered on the expected phase",
	function(candidate): boolean
		local bindingStatus = candidate.BindingStatus
		local runtimeBinding = candidate.RuntimeBinding
		local pollStatus = if type(bindingStatus) == "table" then bindingStatus.Poll else nil
		if type(pollStatus) ~= "table" or type(pollStatus.RegisteredPhases) ~= "table" then
			return false
		end

		return type(runtimeBinding) == "table"
			and _ContainsPhase(pollStatus.RegisteredPhases, runtimeBinding.PollPhase)
	end
)

local HasBindingSyncMethod = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI bound service field is missing SyncDirtyEntities",
	function(candidate): boolean
		local bindingStatus = candidate.BindingStatus
		local syncStatus = if type(bindingStatus) == "table" then bindingStatus.Sync else nil
		return type(syncStatus) == "table" and syncStatus.HasMethod == true
	end
)

local HasBindingSyncPhase = Spec.new(
	"InvalidRuntimeBindingOwner",
	"AI bound service field SyncDirtyEntities is not registered on the expected phase",
	function(candidate): boolean
		local bindingStatus = candidate.BindingStatus
		local runtimeBinding = candidate.RuntimeBinding
		local syncStatus = if type(bindingStatus) == "table" then bindingStatus.Sync else nil
		if type(syncStatus) ~= "table" or type(syncStatus.RegisteredPhases) ~= "table" then
			return false
		end

		return type(runtimeBinding) == "table"
			and _ContainsPhase(syncStatus.RegisteredPhases, runtimeBinding.SyncPhase)
	end
)

return table.freeze({
	HasActorType = HasActorType,
	HasArchetypeName = HasArchetypeName,
	HasAdapterTable = HasAdapterTable,
	HasRegistrationTable = HasRegistrationTable,
	HasSemanticRequirements = Spec.All({
		HasSemanticRequirementsTable,
		HasFactsDependOnPollingBooleanOrNil,
		HasAttributesDependOnProjectionBooleanOrNil,
	}),
	HasRuntimeBinding = Spec.All({
		HasRuntimeBindingTable,
		HasServiceField,
		HasPollPhaseStringOrNil,
		HasSyncPhaseStringOrNil,
	}),
	HasRegistrationOptions = Spec.All({
		HasRegistrationOptionsTable,
		HasRuntimeOwnerTableOrNil,
		HasRuntimeOwnerGetSchedulerBindingStatus,
	}),
	HasHooksTable = HasHooksTable,
	HasActionDefinitionsTable = HasActionDefinitionsTable,
	HasActionPack = HasActionPackTable:And(HasActionPackName),
	HasBehaviorRegistrationName = HasBehaviorRegistrationName,
	HasNonNegativeTickInterval = HasNonNegativeTickInterval,
	HasBehaviorRegistrationTable = HasBehaviorRegistrationTable,
	HasAssignmentRequestTable = HasAssignmentRequestTable,
	HasActorSetupRequest = HasActorSetupRequestTable:And(HasActorSetupRequestEntity),
	HasActorSetupResult = HasActorSetupResultTable:And(HasActorSetupResultEntity):And(HasActorSetupResultFoundBoolean),
	HasActorSetupWriteConfig = HasActorSetupWriteConfigTable:And(HasActorSetupWriteFunction),
	HasFactorySetupWriteConfig = HasFactorySetupWriteConfigTable:And(HasFactorySetupFactory):And(HasFactorySetupWriteSurface),
	HasBehaviorCatalogConfigTable = HasBehaviorCatalogConfigTable,
	HasFolderInstance = HasFolderInstance,
	HasSystemConfig = Spec.All({
		HasSystemConfigTable,
		HasSystemConditionsTable,
		HasSystemCommandsTable,
		HasSystemErrorSinkFunctionOrNil,
	}),
	HasRuntime = Spec.All({
		HasRuntimeTable,
		HasRuntimeRegisterActorType,
		HasRuntimeRegisterActions,
		HasRuntimeBuildTree,
	}),
	HasBindingResultTable = HasBindingResultTable,
	HasSuccessfulBindingResult = HasSuccessfulBindingResult,
	HasBindingStatusTable = HasBindingStatusTable,
	HasBindingTarget = HasBindingTarget,
	HasBindingPollMethod = HasBindingPollMethod,
	HasBindingPollPhase = HasBindingPollPhase,
	HasBindingSyncMethod = HasBindingSyncMethod,
	HasBindingSyncPhase = HasBindingSyncPhase,
})
