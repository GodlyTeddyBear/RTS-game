--!strict

local Types = require(script.Parent.Types)

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

--[=[
	@class AIValidation
	Centralizes input-shape checks for the shared AI facade builder and catalog helpers.
	@server
	@client
]=]

local Validation = {}

-- Core identity checks
function Validation.ValidateActorType(actorType: string)
	assert(type(actorType) == "string" and #actorType > 0, "AI actorType must be a non-empty string")
end

function Validation.ValidateArchetypeName(archetypeName: string)
	assert(type(archetypeName) == "string" and #archetypeName > 0, "AI archetype name must be a non-empty string")
end

function Validation.ValidateAdapter(adapter: TActorAdapter)
	assert(type(adapter) == "table", "AI adapter must be a table")
end

-- Bundle and package shapes
function Validation.ValidateRegistration(registration: TActorRegistration)
	assert(type(registration) == "table", "AI actor registration must be a table")
	Validation.ValidateActorType(registration.ActorType)
	Validation.ValidateAdapter(registration.Adapter)
end

function Validation.ValidateActorBundle(bundle: TActorBundle)
	assert(type(bundle) == "table", "AI actor bundle must be a table")
	Validation.ValidateActorType(bundle.ActorType)
	Validation.ValidateAdapter(bundle.Adapter)

	if bundle.Actions ~= nil then
		Validation.ValidateActionDefinitions(bundle.Actions)
	end

	if bundle.ActionPacks ~= nil then
		assert(type(bundle.ActionPacks) == "table", "AI actor bundle action packs must be an array")
		for _, actionPack in ipairs(bundle.ActionPacks) do
			Validation.ValidateActionPack(actionPack)
		end
	end

	if bundle.DefaultBehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(bundle.DefaultBehaviorName)
	end

	if bundle.Hooks ~= nil then
		Validation.ValidateHooks(bundle.Hooks)
	end

	if bundle.TickInterval ~= nil then
		Validation.ValidateTickInterval(bundle.TickInterval)
	end

	if bundle.InitializeActionState ~= nil then
		assert(type(bundle.InitializeActionState) == "boolean", "AI actor bundle InitializeActionState must be a boolean")
	end
end

function Validation.ValidateActorBundles(bundles: { TActorBundle })
	assert(type(bundles) == "table", "AI actor bundles must be an array")
	for _, bundle in ipairs(bundles) do
		Validation.ValidateActorBundle(bundle)
	end
end

function Validation.ValidateActorPackage(actorPackage: TActorPackage)
	assert(type(actorPackage) == "table", "AI actor package must be a table")
	Validation.ValidateActorBundle(actorPackage.ActorBundle)

	if actorPackage.Behaviors ~= nil then
		Validation.ValidateBehaviorDefinitions(actorPackage.Behaviors)
	end

	if actorPackage.Aliases ~= nil then
		assert(type(actorPackage.Aliases) == "table", "AI actor package aliases must be a table")
		for aliasName, behaviorName in actorPackage.Aliases do
			Validation.ValidateBehaviorAlias(aliasName, behaviorName)
		end
	end

	if actorPackage.ArchetypeDefaults ~= nil then
		assert(type(actorPackage.ArchetypeDefaults) == "table", "AI actor package archetype defaults must be a table")
		for archetypeName, behaviorName in actorPackage.ArchetypeDefaults do
			Validation.ValidateArchetypeName(archetypeName)
			Validation.ValidateBehaviorRegistrationName(behaviorName)
		end
	end

	if actorPackage.FallbackBehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(actorPackage.FallbackBehaviorName)
	end

	if actorPackage.TickInterval ~= nil then
		Validation.ValidateTickInterval(actorPackage.TickInterval)
	end

	if actorPackage.InitializeActionState ~= nil then
		assert(type(actorPackage.InitializeActionState) == "boolean", "AI actor package InitializeActionState must be a boolean")
	end
end

function Validation.ValidateActorPackages(actorPackages: { TActorPackage })
	assert(type(actorPackages) == "table", "AI actor packages must be an array")
	for _, actorPackage in ipairs(actorPackages) do
		Validation.ValidateActorPackage(actorPackage)
	end
end

-- Shared registration payloads
function Validation.ValidateHooks(hooks: { any })
	assert(type(hooks) == "table", "AI hooks must be an array")
end

function Validation.ValidateActionDefinitions(actionDefinitions: { [string]: any })
	assert(type(actionDefinitions) == "table", "AI action definitions must be a table")
end

function Validation.ValidateActionPack(actionPack: TActionPack)
	assert(type(actionPack) == "table", "AI action pack must be a table")
	assert(type(actionPack.Name) == "string" and #actionPack.Name > 0, "AI action pack name must be a non-empty string")
	Validation.ValidateActionDefinitions(actionPack.Definitions)
end

function Validation.ValidateBehaviorRegistrationName(name: string)
	assert(type(name) == "string" and #name > 0, "AI behavior registration name must be a non-empty string")
end

function Validation.ValidateTickInterval(tickInterval: number)
	assert(type(tickInterval) == "number" and tickInterval >= 0, "AI tick interval must be a non-negative number")
end

function Validation.ValidateBehaviorRegistration(registration: TBehaviorRegistration)
	assert(type(registration) == "table", "AI behavior registration must be a table")
	Validation.ValidateBehaviorRegistrationName(registration.Name)
end

function Validation.ValidateBehaviorDefinitions(behaviorDefinitions: { [string]: any })
	assert(type(behaviorDefinitions) == "table", "AI behavior definitions must be a table")
	for name in behaviorDefinitions do
		Validation.ValidateBehaviorRegistrationName(name)
	end
end

function Validation.ValidateBehaviorAlias(aliasName: string, behaviorName: string)
	Validation.ValidateBehaviorRegistrationName(aliasName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
end

-- Assignment and setup resolution
function Validation.ValidateAssignmentRequest(request: TAssignmentRequest)
	assert(type(request) == "table", "AI assignment request must be a table")
	Validation.ValidateActorType(request.ActorType)

	if request.BehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(request.BehaviorName)
	end

	if request.ArchetypeName ~= nil then
		Validation.ValidateArchetypeName(request.ArchetypeName)
	end
end

function Validation.ValidateAssignmentRequests(requests: { TAssignmentRequest })
	assert(type(requests) == "table", "AI assignment requests must be an array")
	for _, request in ipairs(requests) do
		Validation.ValidateAssignmentRequest(request)
	end
end

function Validation.ValidateActorSetupRequest(request: Types.TActorSetupRequest)
	assert(type(request) == "table", "AI actor setup request must be a table")
	assert(type(request.Entity) == "number", "AI actor setup request.Entity must be a number")
	Validation.ValidateAssignmentRequest({
		ActorType = request.ActorType,
		BehaviorName = request.BehaviorName,
		ArchetypeName = request.ArchetypeName,
	})
end

function Validation.ValidateActorSetupRequests(requests: { Types.TActorSetupRequest })
	assert(type(requests) == "table", "AI actor setup requests must be an array")
	for _, request in ipairs(requests) do
		Validation.ValidateActorSetupRequest(request)
	end
end

function Validation.ValidateActorSetupResult(setupResult: Types.TActorSetupResult)
	assert(type(setupResult) == "table", "AI actor setup result must be a table")
	assert(type(setupResult.Entity) == "number", "AI actor setup result.Entity must be a number")
	Validation.ValidateActorType(setupResult.ActorType)
	assert(type(setupResult.Found) == "boolean", "AI actor setup result.Found must be a boolean")

	if setupResult.BehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(setupResult.BehaviorName)
	end

	if setupResult.ResolvedBehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(setupResult.ResolvedBehaviorName)
	end
end

function Validation.ValidateActorSetupResults(setupResults: { Types.TActorSetupResult })
	assert(type(setupResults) == "table", "AI actor setup results must be an array")
	for _, setupResult in ipairs(setupResults) do
		Validation.ValidateActorSetupResult(setupResult)
	end
end

-- Setup write contracts
function Validation.ValidateActorSetupWriteConfig(config: Types.TActorSetupWriteConfig)
	assert(type(config) == "table", "AI actor setup write config must be a table")
	assert(type(config.WriteSetup) == "function", "AI actor setup write config.WriteSetup must be a function")

	if config.ClearActionState ~= nil then
		assert(type(config.ClearActionState) == "function", "AI actor setup write config.ClearActionState must be a function")
	end

	if config.OnMissingBehavior ~= nil then
		assert(type(config.OnMissingBehavior) == "function", "AI actor setup write config.OnMissingBehavior must be a function")
	end
end

function Validation.ValidateFactorySetupWriteConfig(config: Types.TFactorySetupWriteConfig)
	assert(type(config) == "table", "AI factory setup write config must be a table")
	assert(config.Factory ~= nil, "AI factory setup write config.Factory is required")

	-- Factory setup writers accept either method names or direct callbacks so callers can stay close to their own APIs.
	local writeSetupType = type(config.WriteSetup)
	assert(
		writeSetupType == "string" or writeSetupType == "function",
		"AI factory setup write config.WriteSetup must be a method-name string or function"
	)

	if config.ClearActionState ~= nil then
		local clearType = type(config.ClearActionState)
		assert(
			clearType == "string" or clearType == "function",
			"AI factory setup write config.ClearActionState must be a method-name string or function"
		)
	end

	if config.OnMissingBehavior ~= nil then
		local missingType = type(config.OnMissingBehavior)
		assert(
			missingType == "string" or missingType == "function",
			"AI factory setup write config.OnMissingBehavior must be a method-name string or function"
		)
	end
end

-- Catalog and runtime surfaces
function Validation.ValidateBehaviorCatalogConfig(config: TBehaviorCatalogConfig)
	assert(type(config) == "table", "AI behavior catalog config must be a table")

	if config.Behaviors ~= nil then
		Validation.ValidateBehaviorDefinitions(config.Behaviors)
	end

	if config.Aliases ~= nil then
		assert(type(config.Aliases) == "table", "AI behavior catalog aliases must be a table")
		for aliasName, behaviorName in config.Aliases do
			Validation.ValidateBehaviorAlias(aliasName, behaviorName)
		end
	end

	if config.ActorDefaults ~= nil then
		assert(type(config.ActorDefaults) == "table", "AI behavior catalog actor defaults must be a table")
		for actorType, behaviorName in config.ActorDefaults do
			Validation.ValidateActorType(actorType)
			Validation.ValidateBehaviorRegistrationName(behaviorName)
		end
	end

	if config.ArchetypeDefaults ~= nil then
		assert(type(config.ArchetypeDefaults) == "table", "AI behavior catalog archetype defaults must be a table")
		for archetypeName, behaviorName in config.ArchetypeDefaults do
			Validation.ValidateArchetypeName(archetypeName)
			Validation.ValidateBehaviorRegistrationName(behaviorName)
		end
	end

	if config.FallbackBehaviorName ~= nil then
		Validation.ValidateBehaviorRegistrationName(config.FallbackBehaviorName)
	end
end

function Validation.ValidateFolder(folder: Instance, registrationKindName: string)
	assert(typeof(folder) == "Instance", ("AI %s folder must be an Instance"):format(registrationKindName))
end

function Validation.ValidateSystemConfig(config: TSystemConfig)
	assert(type(config) == "table", "AI system config must be a table")
	assert(type(config.Conditions) == "table", "AI system config.Conditions must be a table")
	assert(type(config.Commands) == "table", "AI system config.Commands must be a table")

	if config.Hooks ~= nil then
		Validation.ValidateHooks(config.Hooks)
	end

	if config.GlobalHooks ~= nil then
		Validation.ValidateHooks(config.GlobalHooks)
	end

	if config.ErrorSink ~= nil then
		assert(type(config.ErrorSink) == "function", "AI system config.ErrorSink must be a function")
	end
end

function Validation.ValidateRuntime(runtime: TRegisterableRuntime)
	assert(type(runtime) == "table", "AI runtime must be a table")
	assert(type((runtime :: any).RegisterActorType) == "function", "AI runtime must expose RegisterActorType")
	assert(type((runtime :: any).RegisterActions) == "function", "AI runtime must expose RegisterActions")
	assert(type((runtime :: any).BuildTree) == "function", "AI runtime must expose BuildTree")
end

return table.freeze(Validation)
