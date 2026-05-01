--!strict

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
	_AssertSatisfied(
		AIShapeSpec.HasActorType:IsSatisfiedBy({
			ActorType = actorType,
		}),
		"AI actorType is invalid"
	)
end

function AIValidationPolicy.CheckArchetypeName(archetypeName: any)
	_AssertSatisfied(
		AIShapeSpec.HasArchetypeName:IsSatisfiedBy({
			ArchetypeName = archetypeName,
		}),
		"AI archetype name is invalid"
	)
end

function AIValidationPolicy.CheckAdapter(adapter: any)
	_AssertSatisfied(
		AIShapeSpec.HasAdapterTable:IsSatisfiedBy({
			Adapter = adapter,
		}),
		"AI adapter is invalid"
	)
end

function AIValidationPolicy.CheckSemanticRequirements(requirements: any)
	_AssertSatisfied(
		AIShapeSpec.HasSemanticRequirements:IsSatisfiedBy({
			Requirements = requirements,
		}),
		"AI semantic requirements are invalid"
	)
end

function AIValidationPolicy.CheckRuntimeBinding(runtimeBinding: any)
	_AssertSatisfied(
		AIShapeSpec.HasRuntimeBinding:IsSatisfiedBy({
			RuntimeBinding = runtimeBinding,
		}),
		"AI runtime binding is invalid"
	)
end

function AIValidationPolicy.CheckRegistrationOptions(options: any?)
	if options == nil then
		return
	end

	_AssertSatisfied(
		AIShapeSpec.HasRegistrationOptions:IsSatisfiedBy({
			Options = options,
		}),
		"AI registration validation options are invalid"
	)
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
	_AssertSatisfied(
		AIShapeSpec.HasBindingResultTable:IsSatisfiedBy({
			BindingResult = bindingResult,
		}),
		("AI actor '%s' runtime owner returned an invalid binding response"):format(actorType)
	)
	_AssertSatisfied(
		AIShapeSpec.HasSuccessfulBindingResult:IsSatisfiedBy({
			BindingResult = bindingResult,
		}),
		("AI actor '%s' runtime owner failed to resolve binding for '%s'"):format(
			actorType,
			runtimeBinding.ServiceField
		)
	)
	_AssertSatisfied(
		AIShapeSpec.HasBindingStatusTable:IsSatisfiedBy({
			BindingResult = bindingResult,
		}),
		("AI actor '%s' runtime owner returned an invalid binding status"):format(actorType)
	)

	local bindingStatus = bindingResult.value
	local bindingCandidate = {
		BindingStatus = bindingStatus,
		RuntimeBinding = runtimeBinding,
	}

	_AssertSatisfied(
		AIShapeSpec.HasBindingTarget:IsSatisfiedBy(bindingCandidate),
		("AI actor '%s' bound service field '%s' does not exist"):format(actorType, runtimeBinding.ServiceField)
	)

	if requirements ~= nil and requirements.FactsDependOnPolling == true then
		_AssertSatisfied(
			AIShapeSpec.HasBindingPollMethod:IsSatisfiedBy(bindingCandidate),
			("AI actor '%s' requires FactsDependOnPolling but '%s.Poll' is missing"):format(
				actorType,
				runtimeBinding.ServiceField
			)
		)
		_AssertSatisfied(
			AIShapeSpec.HasBindingPollPhase:IsSatisfiedBy(bindingCandidate),
			("AI actor '%s' requires FactsDependOnPolling but '%s.Poll' is not registered on phase '%s'"):format(
				actorType,
				runtimeBinding.ServiceField,
				tostring(runtimeBinding.PollPhase)
			)
		)
	end

	if requirements ~= nil and requirements.AttributesDependOnProjection == true then
		_AssertSatisfied(
			AIShapeSpec.HasBindingSyncMethod:IsSatisfiedBy(bindingCandidate),
			("AI actor '%s' requires AttributesDependOnProjection but '%s.SyncDirtyEntities' is missing"):format(
				actorType,
				runtimeBinding.ServiceField
			)
		)
		_AssertSatisfied(
			AIShapeSpec.HasBindingSyncPhase:IsSatisfiedBy(bindingCandidate),
			("AI actor '%s' requires AttributesDependOnProjection but '%s.SyncDirtyEntities' is not registered on phase '%s'"):format(
				actorType,
				runtimeBinding.ServiceField,
				tostring(runtimeBinding.SyncPhase)
			)
		)
	end
end

function AIValidationPolicy.CheckRegistration(registration: any)
	_AssertSatisfied(
		AIShapeSpec.HasRegistrationTable:IsSatisfiedBy({
			Registration = registration,
		}),
		"AI actor registration is invalid"
	)

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
	_AssertSatisfied(
		AIShapeSpec.HasHooksTable:IsSatisfiedBy({
			Hooks = hooks,
		}),
		"AI hooks are invalid"
	)
end

function AIValidationPolicy.CheckActionDefinitions(actionDefinitions: any)
	_AssertSatisfied(
		AIShapeSpec.HasActionDefinitionsTable:IsSatisfiedBy({
			ActionDefinitions = actionDefinitions,
		}),
		"AI action definitions are invalid"
	)
end

function AIValidationPolicy.CheckActionPack(actionPack: any)
	_AssertSatisfied(
		AIShapeSpec.HasActionPack:IsSatisfiedBy({
			ActionPack = actionPack,
		}),
		"AI action pack is invalid"
	)
	AIValidationPolicy.CheckActionDefinitions(actionPack.Definitions)
end

function AIValidationPolicy.CheckBehaviorRegistrationName(name: any)
	_AssertSatisfied(
		AIShapeSpec.HasBehaviorRegistrationName:IsSatisfiedBy({
			Name = name,
		}),
		"AI behavior registration name is invalid"
	)
end

function AIValidationPolicy.CheckTickInterval(tickInterval: any)
	_AssertSatisfied(
		AIShapeSpec.HasNonNegativeTickInterval:IsSatisfiedBy({
			TickInterval = tickInterval,
		}),
		"AI tick interval is invalid"
	)
end

function AIValidationPolicy.CheckBehaviorRegistration(registration: any)
	_AssertSatisfied(
		AIShapeSpec.HasBehaviorRegistrationTable:IsSatisfiedBy({
			Registration = registration,
		}),
		"AI behavior registration is invalid"
	)
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
	_AssertSatisfied(
		AIShapeSpec.HasAssignmentRequestTable:IsSatisfiedBy({
			Request = request,
		}),
		"AI assignment request is invalid"
	)
	AIValidationPolicy.CheckActorType(request.ActorType)

	if request.BehaviorName ~= nil then
		AIValidationPolicy.CheckBehaviorRegistrationName(request.BehaviorName)
	end

	if request.ArchetypeName ~= nil then
		AIValidationPolicy.CheckArchetypeName(request.ArchetypeName)
	end
end

function AIValidationPolicy.CheckAssignmentRequests(requests: any)
	assert(type(requests) == "table", "AI assignment requests must be an array")
	for _, request in ipairs(requests) do
		AIValidationPolicy.CheckAssignmentRequest(request)
	end
end

function AIValidationPolicy.CheckActorSetupRequest(request: any)
	_AssertSatisfied(
		AIShapeSpec.HasActorSetupRequest:IsSatisfiedBy({
			Request = request,
		}),
		"AI actor setup request is invalid"
	)
	AIValidationPolicy.CheckAssignmentRequest({
		ActorType = request.ActorType,
		BehaviorName = request.BehaviorName,
		ArchetypeName = request.ArchetypeName,
	})
end

function AIValidationPolicy.CheckActorSetupRequests(requests: any)
	assert(type(requests) == "table", "AI actor setup requests must be an array")
	for _, request in ipairs(requests) do
		AIValidationPolicy.CheckActorSetupRequest(request)
	end
end

function AIValidationPolicy.CheckActorSetupResult(setupResult: any)
	_AssertSatisfied(
		AIShapeSpec.HasActorSetupResult:IsSatisfiedBy({
			SetupResult = setupResult,
		}),
		"AI actor setup result is invalid"
	)
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
	_AssertSatisfied(
		AIShapeSpec.HasActorSetupWriteConfig:IsSatisfiedBy({
			Config = config,
		}),
		"AI actor setup write config is invalid"
	)

	if config.ClearActionState ~= nil then
		assert(type(config.ClearActionState) == "function", "AI actor setup write config.ClearActionState must be a function")
	end

	if config.OnMissingBehavior ~= nil then
		assert(type(config.OnMissingBehavior) == "function", "AI actor setup write config.OnMissingBehavior must be a function")
	end
end

function AIValidationPolicy.CheckFactorySetupWriteConfig(config: any)
	_AssertSatisfied(
		AIShapeSpec.HasFactorySetupWriteConfig:IsSatisfiedBy({
			Config = config,
		}),
		"AI factory setup write config is invalid"
	)

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
	_AssertSatisfied(
		AIShapeSpec.HasBehaviorCatalogConfigTable:IsSatisfiedBy({
			Config = config,
		}),
		"AI behavior catalog config is invalid"
	)

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
	_AssertSatisfied(
		AIShapeSpec.HasFolderInstance:IsSatisfiedBy({
			Folder = folder,
		}),
		("AI %s folder is invalid"):format(registrationKindName)
	)
end

function AIValidationPolicy.CheckSystemConfig(config: any)
	_AssertSatisfied(
		AIShapeSpec.HasSystemConfig:IsSatisfiedBy({
			Config = config,
		}),
		"AI system config is invalid"
	)

	if config.Hooks ~= nil then
		AIValidationPolicy.CheckHooks(config.Hooks)
	end

	if config.GlobalHooks ~= nil then
		AIValidationPolicy.CheckHooks(config.GlobalHooks)
	end

	AIValidationPolicy.CheckRegistrationOptions({
		RuntimeOwner = config.RuntimeOwner,
	})
end

function AIValidationPolicy.CheckRuntime(runtime: any)
	_AssertSatisfied(
		AIShapeSpec.HasRuntime:IsSatisfiedBy({
			Runtime = runtime,
		}),
		"AI runtime is invalid"
	)
end

return table.freeze(AIValidationPolicy)
