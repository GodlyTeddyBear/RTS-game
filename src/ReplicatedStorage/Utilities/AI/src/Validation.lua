--!strict

local Types = require(script.Parent.Types)

type TActorRegistration = Types.TActorRegistration
type TActorBundle = Types.TActorBundle
type TActionPack = Types.TActionPack
type TActorAdapter = Types.TActorAdapter
type TRegisterableRuntime = Types.TRegisterableRuntime
type TBehaviorRegistration = Types.TBehaviorRegistration
type TBehaviorCatalogConfig = Types.TBehaviorCatalogConfig
type TAssignmentRequest = Types.TAssignmentRequest
type TSystemConfig = Types.TSystemConfig

local Validation = {}

function Validation.ValidateActorType(actorType: string)
	assert(type(actorType) == "string" and #actorType > 0, "AI actorType must be a non-empty string")
end

function Validation.ValidateArchetypeName(archetypeName: string)
	assert(type(archetypeName) == "string" and #archetypeName > 0, "AI archetype name must be a non-empty string")
end

function Validation.ValidateAdapter(adapter: TActorAdapter)
	assert(type(adapter) == "table", "AI adapter must be a table")
end

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
end

function Validation.ValidateActorBundles(bundles: { TActorBundle })
	assert(type(bundles) == "table", "AI actor bundles must be an array")
	for _, bundle in ipairs(bundles) do
		Validation.ValidateActorBundle(bundle)
	end
end

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
