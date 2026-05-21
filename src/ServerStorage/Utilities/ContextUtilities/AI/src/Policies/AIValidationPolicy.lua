--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ScratchRecycler = require(ServerStorage.Utilities.ContextUtilities.AI.src.Infrastructure.ScratchRecycler)
local AIShapeSpec = require(script.Parent.Parent.Specs.AIShapeSpec)

local AIValidationPolicy = {}

local function _BuildFailureMessage(prefix: string, result: any): string
	if type(result) == "table" and result.message ~= nil then
		return ("%s: %s"):format(prefix, tostring(result.message))
	end

	return prefix
end

local function _AssertSatisfied(result: any, prefix: string)
	assert(result.success, _BuildFailureMessage(prefix, result))
end

local function _CreateCandidateMap()
	return ScratchRecycler.AcquireMap()
end

local function _ReleaseCandidateMap(candidate: { [any]: any })
	ScratchRecycler.ReleaseMap(candidate)
end

local function _CheckRegistrationOptionsValue(options: any)
	local candidate = _CreateCandidateMap()
	candidate.Options = options

	local result = AIShapeSpec.HasRegistrationOptions:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	return result
end

local function _CheckAssignmentRequestFields(actorType: any, behaviorName: any, archetypeName: any)
	AIValidationPolicy.CheckActorType(actorType)

	if behaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(behaviorName)
	end

	if archetypeName ~= nil then
		AIValidationPolicy.CheckArchetypeName(archetypeName)
	end
end

local function _RequiresRuntimeBinding(requirements: any): boolean
	if requirements == nil then
		return false
	end

	return requirements.FactsDependOnPolling == true or requirements.AttributesDependOnProjection == true
end

function AIValidationPolicy.ContainsPhase(registeredPhases: { string }, expectedPhase: string?): boolean
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

function AIValidationPolicy.CheckActorType(actorType: any)
	local candidate = _CreateCandidateMap()
	candidate.ActorType = actorType

	local result = AIShapeSpec.HasActorType:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI actorType is invalid")
end

function AIValidationPolicy.CheckArchetypeName(archetypeName: any)
	local candidate = _CreateCandidateMap()
	candidate.ArchetypeName = archetypeName

	local result = AIShapeSpec.HasArchetypeName:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI archetype name is invalid")
end

function AIValidationPolicy.CheckAdapter(adapter: any)
	local candidate = _CreateCandidateMap()
	candidate.Adapter = adapter

	local result = AIShapeSpec.HasAdapterTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI adapter is invalid")
end

function AIValidationPolicy.CheckSemanticRequirements(requirements: any)
	local candidate = _CreateCandidateMap()
	candidate.Requirements = requirements

	local result = AIShapeSpec.HasSemanticRequirements:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI semantic requirements are invalid")
end

function AIValidationPolicy.CheckRuntimeBinding(runtimeBinding: any)
	local candidate = _CreateCandidateMap()
	candidate.RuntimeBinding = runtimeBinding

	local result = AIShapeSpec.HasRuntimeBinding:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI runtime binding is invalid")
end

function AIValidationPolicy.CheckRegistrationOptions(options: any?)
	if options == nil then
		return
	end

	local result = _CheckRegistrationOptionsValue(options)
	_AssertSatisfied(result, "AI registration validation options are invalid")
end

function AIValidationPolicy.CheckSemanticContract(actorType: any, requirements: any?, runtimeBinding: any?, options: any?)
	AIValidationPolicy.CheckActorType(actorType)
	AIValidationPolicy.CheckRegistrationOptions(options)

	if requirements ~= nil then
		AIValidationPolicy.CheckSemanticRequirements(requirements)
	end

	if runtimeBinding ~= nil then
		AIValidationPolicy.CheckRuntimeBinding(runtimeBinding)
	end

	if not _RequiresRuntimeBinding(requirements) then
		return
	end

	assert(
		runtimeBinding ~= nil,
		("AI actor '%s' requires RuntimeBinding when semantic requirements declare polling or projection dependence"):format(
			actorType
		)
	)

	assert(
		options ~= nil and options.RuntimeOwner ~= nil,
		("AI actor '%s' requires a RuntimeOwner when semantic requirements are declared"):format(actorType)
	)

	local bindingResult = options.RuntimeOwner:GetSchedulerBindingStatus(runtimeBinding.ServiceField)
	local bindingResultCandidate = _CreateCandidateMap()
	bindingResultCandidate.BindingResult = bindingResult

	local bindingTableResult = AIShapeSpec.HasBindingResultTable:IsSatisfiedBy(bindingResultCandidate)
	_ReleaseCandidateMap(bindingResultCandidate)
	_AssertSatisfied(
		bindingTableResult,
		("AI actor '%s' runtime owner returned an invalid binding response"):format(actorType)
	)

	local successfulBindingCandidate = _CreateCandidateMap()
	successfulBindingCandidate.BindingResult = bindingResult

	local successfulBindingResult = AIShapeSpec.HasSuccessfulBindingResult:IsSatisfiedBy(successfulBindingCandidate)
	_ReleaseCandidateMap(successfulBindingCandidate)
	_AssertSatisfied(
		successfulBindingResult,
		("AI actor '%s' runtime owner failed to resolve binding for '%s'"):format(
			actorType,
			runtimeBinding.ServiceField
		)
	)

	local bindingStatusCandidate = _CreateCandidateMap()
	bindingStatusCandidate.BindingResult = bindingResult

	local bindingStatusResult = AIShapeSpec.HasBindingStatusTable:IsSatisfiedBy(bindingStatusCandidate)
	_ReleaseCandidateMap(bindingStatusCandidate)
	_AssertSatisfied(
		bindingStatusResult,
		("AI actor '%s' runtime owner returned an invalid binding status"):format(actorType)
	)

	local bindingStatus = bindingResult.value
	local bindingTargetCandidate = _CreateCandidateMap()
	bindingTargetCandidate.BindingStatus = bindingStatus
	bindingTargetCandidate.RuntimeBinding = runtimeBinding

	local bindingTargetResult = AIShapeSpec.HasBindingTarget:IsSatisfiedBy(bindingTargetCandidate)
	_ReleaseCandidateMap(bindingTargetCandidate)
	_AssertSatisfied(
		bindingTargetResult,
		("AI actor '%s' bound service field '%s' does not exist"):format(actorType, runtimeBinding.ServiceField)
	)

	if requirements ~= nil and requirements.FactsDependOnPolling == true then
		local bindingPollMethodCandidate = _CreateCandidateMap()
		bindingPollMethodCandidate.BindingStatus = bindingStatus
		bindingPollMethodCandidate.RuntimeBinding = runtimeBinding

		local bindingPollMethodResult = AIShapeSpec.HasBindingPollMethod:IsSatisfiedBy(bindingPollMethodCandidate)
		_ReleaseCandidateMap(bindingPollMethodCandidate)
		_AssertSatisfied(
			bindingPollMethodResult,
			("AI actor '%s' requires FactsDependOnPolling but '%s.Poll' is missing"):format(
				actorType,
				runtimeBinding.ServiceField
			)
		)
		local bindingPollPhaseCandidate = _CreateCandidateMap()
		bindingPollPhaseCandidate.BindingStatus = bindingStatus
		bindingPollPhaseCandidate.RuntimeBinding = runtimeBinding

		local bindingPollPhaseResult = AIShapeSpec.HasBindingPollPhase:IsSatisfiedBy(bindingPollPhaseCandidate)
		_ReleaseCandidateMap(bindingPollPhaseCandidate)
		_AssertSatisfied(
			bindingPollPhaseResult,
			("AI actor '%s' requires FactsDependOnPolling but '%s.Poll' is not registered on phase '%s'"):format(
				actorType,
				runtimeBinding.ServiceField,
				tostring(runtimeBinding.PollPhase)
			)
		)
	end

	if requirements ~= nil and requirements.AttributesDependOnProjection == true then
		local bindingSyncMethodCandidate = _CreateCandidateMap()
		bindingSyncMethodCandidate.BindingStatus = bindingStatus
		bindingSyncMethodCandidate.RuntimeBinding = runtimeBinding

		local bindingSyncMethodResult = AIShapeSpec.HasBindingSyncMethod:IsSatisfiedBy(bindingSyncMethodCandidate)
		_ReleaseCandidateMap(bindingSyncMethodCandidate)
		_AssertSatisfied(
			bindingSyncMethodResult,
			("AI actor '%s' requires AttributesDependOnProjection but '%s.SyncDirtyEntities' is missing"):format(
				actorType,
				runtimeBinding.ServiceField
			)
		)
		local bindingSyncPhaseCandidate = _CreateCandidateMap()
		bindingSyncPhaseCandidate.BindingStatus = bindingStatus
		bindingSyncPhaseCandidate.RuntimeBinding = runtimeBinding

		local bindingSyncPhaseResult = AIShapeSpec.HasBindingSyncPhase:IsSatisfiedBy(bindingSyncPhaseCandidate)
		_ReleaseCandidateMap(bindingSyncPhaseCandidate)
		_AssertSatisfied(
			bindingSyncPhaseResult,
			("AI actor '%s' requires AttributesDependOnProjection but '%s.SyncDirtyEntities' is not registered on phase '%s'"):format(
				actorType,
				runtimeBinding.ServiceField,
				tostring(runtimeBinding.SyncPhase)
			)
		)
	end
end

function AIValidationPolicy.CheckRegistration(registration: any)
	local candidate = _CreateCandidateMap()
	candidate.Registration = registration

	local result = AIShapeSpec.HasRegistrationTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI actor registration is invalid")

	AIValidationPolicy.CheckActorType(registration.ActorType)
	AIValidationPolicy.CheckAdapter(registration.Adapter)

	if (registration :: any).Actions ~= nil then
		AIValidationPolicy.CheckActionDefinitions((registration :: any).Actions)
	end

	if (registration :: any).SemanticRequirements ~= nil then
		AIValidationPolicy.CheckSemanticRequirements((registration :: any).SemanticRequirements)
	end

	if (registration :: any).RuntimeBinding ~= nil then
		AIValidationPolicy.CheckRuntimeBinding((registration :: any).RuntimeBinding)
	end

	if _RequiresRuntimeBinding((registration :: any).SemanticRequirements) then
		assert(
			(registration :: any).RuntimeBinding ~= nil,
			("AI actor registration '%s' requires RuntimeBinding when semantic requirements declare polling or projection dependence"):format(
				registration.ActorType
			)
		)
	end
end

function AIValidationPolicy.CheckRegistrationForUse(registration: any, options: any?)
	AIValidationPolicy.CheckRegistration(registration)
	AIValidationPolicy.CheckSemanticContract(
		registration.ActorType,
		(registration :: any).SemanticRequirements,
		(registration :: any).RuntimeBinding,
		options
	)
end

function AIValidationPolicy.CheckActorBundle(bundle: any)
	assert(type(bundle) == "table", "AI actor bundle must be a table")
	AIValidationPolicy.CheckActorType(bundle.ActorType)
	AIValidationPolicy.CheckAdapter(bundle.Adapter)

	if bundle.Actions ~= nil then
		AIValidationPolicy.CheckActionDefinitions(bundle.Actions)
	end

	if bundle.ActionPacks ~= nil then
		assert(type(bundle.ActionPacks) == "table", "AI actor bundle action packs must be an array")
		for _, actionPack in ipairs(bundle.ActionPacks) do
			AIValidationPolicy.CheckActionPack(actionPack)
		end
	end

	if bundle.DefaultBehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(bundle.DefaultBehaviorName)
	end

	if bundle.Hooks ~= nil then
		AIValidationPolicy.CheckHooks(bundle.Hooks)
	end

	if bundle.TickInterval ~= nil then
		AIValidationPolicy.CheckTickInterval(bundle.TickInterval)
	end

	if bundle.InitializeActionState ~= nil then
		assert(type(bundle.InitializeActionState) == "boolean", "AI actor bundle InitializeActionState must be a boolean")
	end

	if bundle.SemanticRequirements ~= nil then
		AIValidationPolicy.CheckSemanticRequirements(bundle.SemanticRequirements)
	end

	if bundle.RuntimeBinding ~= nil then
		AIValidationPolicy.CheckRuntimeBinding(bundle.RuntimeBinding)
	end

	if _RequiresRuntimeBinding(bundle.SemanticRequirements) then
		assert(
			bundle.RuntimeBinding ~= nil,
			("AI actor bundle '%s' requires RuntimeBinding when semantic requirements declare polling or projection dependence"):format(
				bundle.ActorType
			)
		)
	end
end

function AIValidationPolicy.CheckActorBundleForUse(bundle: any, options: any?)
	AIValidationPolicy.CheckActorBundle(bundle)
	AIValidationPolicy.CheckSemanticContract(bundle.ActorType, bundle.SemanticRequirements, bundle.RuntimeBinding, options)
end

function AIValidationPolicy.CheckActorBundles(bundles: any)
	assert(type(bundles) == "table", "AI actor bundles must be an array")
	for _, bundle in ipairs(bundles) do
		AIValidationPolicy.CheckActorBundle(bundle)
	end
end

function AIValidationPolicy.CheckActorPackage(actorPackage: any)
	assert(type(actorPackage) == "table", "AI actor package must be a table")
	AIValidationPolicy.CheckActorBundle(actorPackage.ActorBundle)

	if actorPackage.Behaviors ~= nil then
		AIValidationPolicy.CheckBehaviorDefinitions(actorPackage.Behaviors)
	end

	if actorPackage.Aliases ~= nil then
		assert(type(actorPackage.Aliases) == "table", "AI actor package aliases must be a table")
		for aliasName, behaviorName in actorPackage.Aliases do
			AIValidationPolicy.CheckBehaviorAlias(aliasName, behaviorName)
		end
	end

	if actorPackage.ArchetypeDefaults ~= nil then
		assert(type(actorPackage.ArchetypeDefaults) == "table", "AI actor package archetype defaults must be a table")
		for archetypeName, behaviorName in actorPackage.ArchetypeDefaults do
			AIValidationPolicy.CheckArchetypeName(archetypeName)
			AIValidationPolicy.CheckBehaviorRegistrationName(behaviorName)
		end
	end

	if actorPackage.FallbackBehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(actorPackage.FallbackBehaviorName)
	end

	if actorPackage.TickInterval ~= nil then
		AIValidationPolicy.CheckTickInterval(actorPackage.TickInterval)
	end

	if actorPackage.InitializeActionState ~= nil then
		assert(type(actorPackage.InitializeActionState) == "boolean", "AI actor package InitializeActionState must be a boolean")
	end
end

function AIValidationPolicy.CheckActorPackageForUse(actorPackage: any, options: any?)
	AIValidationPolicy.CheckActorPackage(actorPackage)
	AIValidationPolicy.CheckActorBundleForUse(actorPackage.ActorBundle, options)
end

function AIValidationPolicy.CheckActorPackages(actorPackages: any)
	assert(type(actorPackages) == "table", "AI actor packages must be an array")
	for _, actorPackage in ipairs(actorPackages) do
		AIValidationPolicy.CheckActorPackage(actorPackage)
	end
end

function AIValidationPolicy.CheckHooks(hooks: any)
	local candidate = _CreateCandidateMap()
	candidate.Hooks = hooks

	local result = AIShapeSpec.HasHooksTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI hooks are invalid")
end

function AIValidationPolicy.CheckActionDefinitions(actionDefinitions: any)
	local candidate = _CreateCandidateMap()
	candidate.ActionDefinitions = actionDefinitions

	local result = AIShapeSpec.HasActionDefinitionsTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI action definitions are invalid")
end

function AIValidationPolicy.CheckActionPack(actionPack: any)
	local candidate = _CreateCandidateMap()
	candidate.ActionPack = actionPack

	local result = AIShapeSpec.HasActionPack:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI action pack is invalid")
	AIValidationPolicy.CheckActionDefinitions(actionPack.Definitions)
end

function AIValidationPolicy.CheckBehaviorRegistrationName(name: any)
	local candidate = _CreateCandidateMap()
	candidate.Name = name

	local result = AIShapeSpec.HasBehaviorRegistrationName:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI behavior registration name is invalid")
end

function AIValidationPolicy.CheckTickInterval(tickInterval: any)
	local candidate = _CreateCandidateMap()
	candidate.TickInterval = tickInterval

	local result = AIShapeSpec.HasNonNegativeTickInterval:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI tick interval is invalid")
end

function AIValidationPolicy.CheckBehaviorRegistration(registration: any)
	local candidate = _CreateCandidateMap()
	candidate.Registration = registration

	local result = AIShapeSpec.HasBehaviorRegistrationTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI behavior registration is invalid")
	AIValidationPolicy.CheckBehaviorRegistrationName(registration.Name)
end

function AIValidationPolicy.CheckBehaviorDefinitions(behaviorDefinitions: any)
	assert(type(behaviorDefinitions) == "table", "AI behavior definitions must be a table")
	for name in behaviorDefinitions do
		AIValidationPolicy.CheckBehaviorRegistrationName(name)
	end
end

function AIValidationPolicy.CheckBehaviorAlias(aliasName: any, behaviorName: any)
	AIValidationPolicy.CheckBehaviorRegistrationName(aliasName)
	AIValidationPolicy.CheckBehaviorRegistrationName(behaviorName)
end

function AIValidationPolicy.CheckAssignmentRequest(request: any)
	local candidate = _CreateCandidateMap()
	candidate.Request = request

	local result = AIShapeSpec.HasAssignmentRequestTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI assignment request is invalid")

	_CheckAssignmentRequestFields(request.ActorType, request.BehaviorName, request.ArchetypeName)
end

function AIValidationPolicy.CheckAssignmentRequests(requests: any)
	assert(type(requests) == "table", "AI assignment requests must be an array")
	for _, request in ipairs(requests) do
		AIValidationPolicy.CheckAssignmentRequest(request)
	end
end

function AIValidationPolicy.CheckActorSetupRequest(request: any)
	local candidate = _CreateCandidateMap()
	candidate.Request = request

	local result = AIShapeSpec.HasActorSetupRequest:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI actor setup request is invalid")

	_CheckAssignmentRequestFields(request.ActorType, request.BehaviorName, request.ArchetypeName)
end

function AIValidationPolicy.CheckActorSetupRequests(requests: any)
	assert(type(requests) == "table", "AI actor setup requests must be an array")
	for _, request in ipairs(requests) do
		AIValidationPolicy.CheckActorSetupRequest(request)
	end
end

function AIValidationPolicy.CheckActorSetupResult(setupResult: any)
	local candidate = _CreateCandidateMap()
	candidate.SetupResult = setupResult

	local result = AIShapeSpec.HasActorSetupResult:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI actor setup result is invalid")
	AIValidationPolicy.CheckActorType(setupResult.ActorType)

	if setupResult.BehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(setupResult.BehaviorName)
	end

	if setupResult.ResolvedBehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(setupResult.ResolvedBehaviorName)
	end
end

function AIValidationPolicy.CheckActorSetupResults(setupResults: any)
	assert(type(setupResults) == "table", "AI actor setup results must be an array")
	for _, setupResult in ipairs(setupResults) do
		AIValidationPolicy.CheckActorSetupResult(setupResult)
	end
end

function AIValidationPolicy.CheckActorSetupWriteConfig(config: any)
	local candidate = _CreateCandidateMap()
	candidate.Config = config

	local result = AIShapeSpec.HasActorSetupWriteConfig:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI actor setup write config is invalid")

	if config.ClearActionState ~= nil then
		assert(type(config.ClearActionState) == "function", "AI actor setup write config.ClearActionState must be a function")
	end

	if config.OnMissingBehavior ~= nil then
		assert(type(config.OnMissingBehavior) == "function", "AI actor setup write config.OnMissingBehavior must be a function")
	end
end

function AIValidationPolicy.CheckFactorySetupWriteConfig(config: any)
	local candidate = _CreateCandidateMap()
	candidate.Config = config

	local result = AIShapeSpec.HasFactorySetupWriteConfig:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI factory setup write config is invalid")

	if config.ClearActionState ~= nil then
		assert(
			type(config.ClearActionState) == "string" or type(config.ClearActionState) == "function",
			"AI factory setup write config.ClearActionState must be a method-name string or function"
		)
	end

	if config.OnMissingBehavior ~= nil then
		assert(
			type(config.OnMissingBehavior) == "string" or type(config.OnMissingBehavior) == "function",
			"AI factory setup write config.OnMissingBehavior must be a method-name string or function"
		)
	end
end

function AIValidationPolicy.CheckBehaviorCatalogConfig(config: any)
	local candidate = _CreateCandidateMap()
	candidate.Config = config

	local result = AIShapeSpec.HasBehaviorCatalogConfigTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI behavior catalog config is invalid")

	if config.Behaviors ~= nil then
		AIValidationPolicy.CheckBehaviorDefinitions(config.Behaviors)
	end

	if config.Aliases ~= nil then
		assert(type(config.Aliases) == "table", "AI behavior catalog aliases must be a table")
		for aliasName, behaviorName in config.Aliases do
			AIValidationPolicy.CheckBehaviorAlias(aliasName, behaviorName)
		end
	end

	if config.ActorDefaults ~= nil then
		assert(type(config.ActorDefaults) == "table", "AI behavior catalog actor defaults must be a table")
		for actorType, behaviorName in config.ActorDefaults do
			AIValidationPolicy.CheckActorType(actorType)
			AIValidationPolicy.CheckBehaviorRegistrationName(behaviorName)
		end
	end

	if config.ArchetypeDefaults ~= nil then
		assert(type(config.ArchetypeDefaults) == "table", "AI behavior catalog archetype defaults must be a table")
		for archetypeName, behaviorName in config.ArchetypeDefaults do
			AIValidationPolicy.CheckArchetypeName(archetypeName)
			AIValidationPolicy.CheckBehaviorRegistrationName(behaviorName)
		end
	end

	if config.FallbackBehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(config.FallbackBehaviorName)
	end
end

function AIValidationPolicy.CheckFolder(folder: any, registrationKindName: string)
	local candidate = _CreateCandidateMap()
	candidate.Folder = folder

	local result = AIShapeSpec.HasFolderInstance:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, ("AI %s folder is invalid"):format(registrationKindName))
end

function AIValidationPolicy.CheckSystemConfig(config: any)
	local candidate = _CreateCandidateMap()
	candidate.Config = config

	local result = AIShapeSpec.HasSystemConfig:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI system config is invalid")

	if config.Hooks ~= nil then
		AIValidationPolicy.CheckHooks(config.Hooks)
	end

	if config.GlobalHooks ~= nil then
		AIValidationPolicy.CheckHooks(config.GlobalHooks)
	end

	local options = _CreateCandidateMap()
	options.RuntimeOwner = config.RuntimeOwner
	local optionsResult = _CheckRegistrationOptionsValue(options)
	_ReleaseCandidateMap(options)
	_AssertSatisfied(optionsResult, "AI registration validation options are invalid")
end

function AIValidationPolicy.CheckRuntime(runtime: any)
	local candidate = _CreateCandidateMap()
	candidate.Runtime = runtime

	local result = AIShapeSpec.HasRuntime:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(result, "AI runtime is invalid")
end

return table.freeze(AIValidationPolicy)
