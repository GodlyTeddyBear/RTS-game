--!strict

local Types = require(script.Parent.Types)
local AIValidationPolicy = require(script.Parent.Policies.AIValidationPolicy)

type TActorRegistration = Types.TActorRegistration
type TActorBundle = Types.TActorBundle
type TActionPack = Types.TActionPack
type TActorPackage = Types.TActorPackage
type TActorAdapter = Types.TActorAdapter
type TRegisterableRuntime = Types.TRegisterableRuntime
type TBehaviorRegistration = Types.TBehaviorRegistration
type TBehaviorCatalogConfig = Types.TBehaviorCatalogConfig
type TAssignmentRequest = Types.TAssignmentRequest
type TSystemConfig = Types.TSystemConfig
type TRegistrationValidationOptions = Types.TRegistrationValidationOptions

--[=[
	@class AIValidation
	Thin assert-based facade over the shared AI validation policy.
	@server
	@client
]=]

local Validation = {}

function Validation.ValidateActorType(actorType: string)
	AIValidationPolicy.CheckActorType(actorType)
end

function Validation.ContainsPhase(registeredPhases: { string }, expectedPhase: string?): boolean
	return AIValidationPolicy.ContainsPhase(registeredPhases, expectedPhase)
end

function Validation.ValidateArchetypeName(archetypeName: string)
	AIValidationPolicy.CheckArchetypeName(archetypeName)
end

function Validation.ValidateAdapter(adapter: TActorAdapter)
	AIValidationPolicy.CheckAdapter(adapter)
end

function Validation.ValidateRegistration(registration: TActorRegistration)
	AIValidationPolicy.CheckRegistration(registration)
end

function Validation.ValidateSemanticRequirements(requirements: Types.TSemanticRequirements)
	AIValidationPolicy.CheckSemanticRequirements(requirements)
end

function Validation.ValidateRuntimeBinding(runtimeBinding: Types.TRuntimeBinding)
	AIValidationPolicy.CheckRuntimeBinding(runtimeBinding)
end

function Validation.ValidateRegistrationOptions(options: TRegistrationValidationOptions?)
	AIValidationPolicy.CheckRegistrationOptions(options)
end

function Validation.ValidateSemanticContract(
	actorType: string,
	requirements: Types.TSemanticRequirements?,
	runtimeBinding: Types.TRuntimeBinding?,
	options: TRegistrationValidationOptions?
)
	AIValidationPolicy.CheckSemanticContract(actorType, requirements, runtimeBinding, options)
end

function Validation.ValidateRegistrationForUse(registration: TActorRegistration, options: TRegistrationValidationOptions?)
	AIValidationPolicy.CheckRegistrationForUse(registration, options)
end

function Validation.ValidateActorBundleForUse(bundle: TActorBundle, options: TRegistrationValidationOptions?)
	AIValidationPolicy.CheckActorBundleForUse(bundle, options)
end

function Validation.ValidateActorBundle(bundle: TActorBundle)
	AIValidationPolicy.CheckActorBundle(bundle)
end

function Validation.ValidateActorBundles(bundles: { TActorBundle })
	AIValidationPolicy.CheckActorBundles(bundles)
end

function Validation.ValidateActorPackage(actorPackage: TActorPackage)
	AIValidationPolicy.CheckActorPackage(actorPackage)
end

function Validation.ValidateActorPackageForUse(actorPackage: TActorPackage, options: TRegistrationValidationOptions?)
	AIValidationPolicy.CheckActorPackageForUse(actorPackage, options)
end

function Validation.ValidateActorPackages(actorPackages: { TActorPackage })
	AIValidationPolicy.CheckActorPackages(actorPackages)
end

function Validation.ValidateHooks(hooks: { any })
	AIValidationPolicy.CheckHooks(hooks)
end

function Validation.ValidateActionDefinitions(actionDefinitions: { [string]: any })
	AIValidationPolicy.CheckActionDefinitions(actionDefinitions)
end

function Validation.ValidateActionPack(actionPack: TActionPack)
	AIValidationPolicy.CheckActionPack(actionPack)
end

function Validation.ValidateBehaviorRegistrationName(name: string)
	AIValidationPolicy.CheckBehaviorRegistrationName(name)
end

function Validation.ValidateTickInterval(tickInterval: number)
	AIValidationPolicy.CheckTickInterval(tickInterval)
end

function Validation.ValidateBehaviorRegistration(registration: TBehaviorRegistration)
	AIValidationPolicy.CheckBehaviorRegistration(registration)
end

function Validation.ValidateBehaviorDefinitions(behaviorDefinitions: { [string]: any })
	AIValidationPolicy.CheckBehaviorDefinitions(behaviorDefinitions)
end

function Validation.ValidateBehaviorAlias(aliasName: string, behaviorName: string)
	AIValidationPolicy.CheckBehaviorAlias(aliasName, behaviorName)
end

function Validation.ValidateAssignmentRequest(request: TAssignmentRequest)
	AIValidationPolicy.CheckAssignmentRequest(request)
end

function Validation.ValidateAssignmentRequests(requests: { TAssignmentRequest })
	AIValidationPolicy.CheckAssignmentRequests(requests)
end

function Validation.ValidateActorSetupRequest(request: Types.TActorSetupRequest)
	AIValidationPolicy.CheckActorSetupRequest(request)
end

function Validation.ValidateActorSetupRequests(requests: { Types.TActorSetupRequest })
	AIValidationPolicy.CheckActorSetupRequests(requests)
end

function Validation.ValidateActorSetupResult(setupResult: Types.TActorSetupResult)
	AIValidationPolicy.CheckActorSetupResult(setupResult)
end

function Validation.ValidateActorSetupResults(setupResults: { Types.TActorSetupResult })
	AIValidationPolicy.CheckActorSetupResults(setupResults)
end

function Validation.ValidateActorSetupWriteConfig(config: Types.TActorSetupWriteConfig)
	AIValidationPolicy.CheckActorSetupWriteConfig(config)
end

function Validation.ValidateFactorySetupWriteConfig(config: Types.TFactorySetupWriteConfig)
	AIValidationPolicy.CheckFactorySetupWriteConfig(config)
end

function Validation.ValidateBehaviorCatalogConfig(config: TBehaviorCatalogConfig)
	AIValidationPolicy.CheckBehaviorCatalogConfig(config)
end

function Validation.ValidateFolder(folder: Instance, registrationKindName: string)
	AIValidationPolicy.CheckFolder(folder, registrationKindName)
end

function Validation.ValidateSystemConfig(config: TSystemConfig)
	AIValidationPolicy.CheckSystemConfig(config)
end

function Validation.ValidateRuntime(runtime: TRegisterableRuntime)
	AIValidationPolicy.CheckRuntime(runtime)
end

return table.freeze(Validation)
