--!strict

--[=[
	@class AIEntry
	Package entry that groups the shared AI utilities behind one import surface.
	@prop Types AITypes -- Grouped type exports for the facade helpers
	@prop Runtime AiRuntimeEntry -- Re-export of the shared AI runtime utility
	@prop AdapterFactory AiAdapterFactoryEntry -- Re-export of the shared adapter factory utility
	@prop Behavior BehaviorSystem -- Re-export of the shared behavior-system utility
	@server
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AiAdapterFactory = require(ReplicatedStorage.Utilities.AI.AdapterFactory)
local AiRuntime = require(ReplicatedStorage.Utilities.AI.Runtime)
local BehaviorSystem = require(ReplicatedStorage.Utilities.AI.Behavior)

local BehaviorCatalog = require(script.BehaviorCatalog)
local Builder = require(script.Builder)
local Types = require(script.Types)
local Validation = require(script.Validation)

local AI = {
	Types = Types,
	Runtime = AiRuntime,
	AdapterFactory = AiAdapterFactory,
	Behavior = BehaviorSystem,
}

export type TRuntimeConfig = Types.TRuntimeConfig
export type TFrameContext = Types.TFrameContext
export type TActorAdapter = Types.TActorAdapter
export type TAdapterConfig = Types.TAdapterConfig
export type TActionPack = Types.TActionPack
export type TActorRegistration = Types.TActorRegistration
export type TActorBundle = Types.TActorBundle
export type TBehaviorCatalog = Types.TBehaviorCatalog
export type TBehaviorCatalogConfig = Types.TBehaviorCatalogConfig
export type TResolveBehaviorOptions = Types.TResolveBehaviorOptions
export type TAssignmentRequest = Types.TAssignmentRequest
export type TAssignmentResult = Types.TAssignmentResult
export type TBehaviorRegistration = Types.TBehaviorRegistration
export type TRegisterableRuntime = Types.TRegisterableRuntime
export type TRunFrameResult = Types.TRunFrameResult
export type TCleanupResult = Types.TCleanupResult
export type TSystemConfig = Types.TSystemConfig
export type TBuildManifest = Types.TBuildManifest
export type TBuildDiagnostics = Types.TBuildDiagnostics
export type TAssignmentDefaults = Types.TAssignmentDefaults
export type TSystemBuildResult = Types.TSystemBuildResult
export type TSystemBuilder = Types.TSystemBuilder

--[=[
	Creates a runtime by forwarding to `AiRuntime.new`.
	@within AIEntry
	@param config TRuntimeConfig
	@return AiRuntimeRuntime
]=]
function AI.CreateRuntime(config: TRuntimeConfig)
	return AiRuntime.new(config)
end

--[=[
	Creates a composition builder that collects AI runtime inputs, actors, and behaviors.
	@within AIEntry
	@param config TSystemConfig
	@return TSystemBuilder
]=]
function AI.CreateSystem(config: TSystemConfig): TSystemBuilder
	return Builder.new(AI, config)
end

--[=[
	Creates a behavior catalog for named behavior resolution and defaults.
	@within AIEntry
	@param config TBehaviorCatalogConfig?
	@return TBehaviorCatalog
]=]
function AI.CreateBehaviorCatalog(config: TBehaviorCatalogConfig?): TBehaviorCatalog
	return BehaviorCatalog.new(config)
end

--[=[
	Creates an actor adapter by forwarding to `AiAdapterFactory.Create`.
	@within AIEntry
	@param config TAdapterConfig
	@return TActorAdapter
]=]
function AI.CreateAdapter(config: TAdapterConfig): TActorAdapter
	return AiAdapterFactory.Create(config)
end

--[=[
	Creates a small registration bundle for one actor type.
	@within AIEntry
	@param registration TActorRegistration
	@return TActorRegistration
]=]
function AI.CreateActorRegistration(registration: TActorRegistration): TActorRegistration
	Validation.ValidateRegistration(registration)

	return table.freeze({
		ActorType = registration.ActorType,
		Adapter = registration.Adapter,
		Actions = registration.Actions,
	})
end

--[=[
	Creates a composable actor bundle for the builder-oriented AI facade.
	@within AIEntry
	@param bundle TActorBundle
	@return TActorBundle
]=]
function AI.CreateActorBundle(bundle: TActorBundle): TActorBundle
	Validation.ValidateActorBundle(bundle)

	return table.freeze({
		ActorType = bundle.ActorType,
		Adapter = bundle.Adapter,
		Actions = bundle.Actions,
		ActionPacks = bundle.ActionPacks,
		DefaultBehaviorName = bundle.DefaultBehaviorName,
		Hooks = bundle.Hooks,
	})
end

--[=[
	Creates an action pack that groups related action definitions.
	@within AIEntry
	@param name string
	@param definitions { [string]: any }
	@return TActionPack
]=]
function AI.CreateActionPack(name: string, definitions: { [string]: any }): TActionPack
	local actionPack = {
		Name = name,
		Definitions = definitions,
	}
	Validation.ValidateActionPack(actionPack)

	return table.freeze({
		Name = name,
		Definitions = table.freeze(table.clone(definitions)),
	})
end

--[=[
	Creates a named behavior registration bundle.
	@within AIEntry
	@param name string
	@param definition any
	@return TBehaviorRegistration
]=]
function AI.CreateBehaviorRegistration(name: string, definition: any): TBehaviorRegistration
	Validation.ValidateBehaviorRegistration({
		Name = name,
		Definition = definition,
	})

	return table.freeze({
		Name = name,
		Definition = definition,
	})
end

--[=[
	Registers one actor adapter and optionally its action definitions on the runtime.
	@within AIEntry
	@param runtime TRegisterableRuntime
	@param actorType string
	@param adapter TActorAdapter
	@param actionDefinitions any?
]=]
function AI.RegisterActor(
	runtime: TRegisterableRuntime,
	actorType: string,
	adapter: TActorAdapter,
	actionDefinitions: any?
)
	Validation.ValidateRuntime(runtime)
	Validation.ValidateActorType(actorType)
	Validation.ValidateAdapter(adapter)

	runtime:RegisterActorType(actorType, adapter)

	if actionDefinitions ~= nil then
		runtime:RegisterActions(actionDefinitions)
	end
end

--[=[
	Registers action definitions on the runtime.
	@within AIEntry
	@param runtime TRegisterableRuntime
	@param definitions any
]=]
function AI.RegisterActions(runtime: TRegisterableRuntime, definitions: any)
	Validation.ValidateRuntime(runtime)
	Validation.ValidateActionDefinitions(definitions)
	runtime:RegisterActions(definitions)
end

--[=[
	Builds many named behaviors from one runtime and definition map.
	@within AIEntry
	@param runtime TRegisterableRuntime
	@param behaviorDefinitions { [string]: any }
	@return { [string]: any }
]=]
function AI.BuildBehaviors(runtime: TRegisterableRuntime, behaviorDefinitions: { [string]: any }): { [string]: any }
	Validation.ValidateRuntime(runtime)
	Validation.ValidateBehaviorDefinitions(behaviorDefinitions)
	return Builder.BuildBehaviors(runtime, behaviorDefinitions)
end

local function _ResolveBehaviorName(
	buildResult: TSystemBuildResult,
	request: TAssignmentRequest
): (string?, string)
	local explicitBehaviorName = request.BehaviorName
	if explicitBehaviorName ~= nil then
		return explicitBehaviorName, Types.Enums.AssignmentSource.Explicit.Name
	end

	local actorDefault = buildResult.ActorDefaults[request.ActorType]
	if actorDefault ~= nil and actorDefault.DefaultBehaviorName ~= nil then
		return actorDefault.DefaultBehaviorName, Types.Enums.AssignmentSource.ActorBundleDefault.Name
	end

	local actorTypeDefault = buildResult.Catalog.ActorDefaults[request.ActorType]
	if actorTypeDefault ~= nil then
		return actorTypeDefault, Types.Enums.AssignmentSource.ActorTypeDefault.Name
	end

	local archetypeName = request.ArchetypeName
	if archetypeName ~= nil then
		local archetypeDefault = buildResult.Catalog.ArchetypeDefaults[archetypeName]
		if archetypeDefault ~= nil then
			return archetypeDefault, Types.Enums.AssignmentSource.ArchetypeDefault.Name
		end
	end

	local fallbackBehaviorName = buildResult.Catalog.FallbackBehaviorName
	if fallbackBehaviorName ~= nil then
		return fallbackBehaviorName, Types.Enums.AssignmentSource.Fallback.Name
	end

	return nil, Types.Enums.AssignmentSource.Missing.Name
end

--[=[
	Resolves the archetype-default built behavior tree from one build result.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param archetypeName string
	@return any?
]=]
function AI.ResolveBehaviorByArchetype(buildResult: TSystemBuildResult, archetypeName: string): any?
	local assignment = AI.ResolveActorAssignment(buildResult, "__Archetype__", {
		ArchetypeName = archetypeName,
	})
	return assignment.Tree
end

--[=[
	Resolves one actor assignment into a plain assignment artifact without mutating ECS.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param actorType string
	@param options TResolveBehaviorOptions?
	@return TAssignmentResult
]=]
function AI.ResolveActorAssignment(
	buildResult: TSystemBuildResult,
	actorType: string,
	options: TResolveBehaviorOptions?
): TAssignmentResult
	local request = {
		ActorType = actorType,
		BehaviorName = if options ~= nil then options.BehaviorName else nil,
		ArchetypeName = if options ~= nil then options.ArchetypeName else nil,
	}
	Validation.ValidateAssignmentRequest(request)
	assert(type(buildResult) == "table", "AI buildResult must be a table")

	local behaviorName, source = _ResolveBehaviorName(buildResult, request)
	local resolvedBehaviorName = if behaviorName ~= nil then (buildResult.Catalog.Aliases[behaviorName] or behaviorName) else nil
	local tree = if resolvedBehaviorName ~= nil then buildResult.Behaviors[resolvedBehaviorName] else nil
	local found = tree ~= nil

	if not found then
		source = Types.Enums.AssignmentSource.Missing.Name
	end

	return table.freeze({
		ActorType = actorType,
		BehaviorName = behaviorName,
		ResolvedBehaviorName = resolvedBehaviorName,
		Tree = tree,
		Source = source,
		ArchetypeName = request.ArchetypeName,
		Found = found,
	})
end

--[=[
	Resolves many actor assignments in input order.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param requests { TAssignmentRequest }
	@return { TAssignmentResult }
]=]
function AI.ResolveAssignments(
	buildResult: TSystemBuildResult,
	requests: { TAssignmentRequest }
): { TAssignmentResult }
	Validation.ValidateAssignmentRequests(requests)
	assert(type(buildResult) == "table", "AI buildResult must be a table")

	local assignmentResults = {}
	for _, request in ipairs(requests) do
		table.insert(assignmentResults, AI.ResolveActorAssignment(buildResult, request.ActorType, {
			BehaviorName = request.BehaviorName,
			ArchetypeName = request.ArchetypeName,
		}))
	end

	return table.freeze(assignmentResults)
end

--[=[
	Resolves the built default behavior tree for one registered actor type.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param actorType string
	@return any?
]=]
function AI.ResolveActorDefaultBehavior(buildResult: TSystemBuildResult, actorType: string): any?
	return AI.ResolveActorAssignment(buildResult, actorType, nil).Tree
end

--[=[
	Resolves the built behavior tree for one actor using bundle defaults, catalog defaults, and fallback rules.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param actorType string
	@param options TResolveBehaviorOptions?
	@return any?
]=]
function AI.ResolveActorBehavior(buildResult: TSystemBuildResult, actorType: string, options: TResolveBehaviorOptions?): any?
	return AI.ResolveActorAssignment(buildResult, actorType, options).Tree
end

--[=[
	Returns the registered actor types from one build result.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@return { string }
]=]
function AI.ListRegisteredActors(buildResult: TSystemBuildResult): { string }
	assert(type(buildResult) == "table", "AI buildResult must be a table")
	return buildResult.Manifest.ActorTypes
end

--[=[
	Returns the registered behavior names from one build result.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@return { string }
]=]
function AI.ListRegisteredBehaviors(buildResult: TSystemBuildResult): { string }
	assert(type(buildResult) == "table", "AI buildResult must be a table")
	return buildResult.Manifest.BehaviorNames
end

--[=[
	Returns the assignment defaults captured in one build result.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@return TAssignmentDefaults
]=]
function AI.ListAssignmentDefaults(buildResult: TSystemBuildResult): TAssignmentDefaults
	assert(type(buildResult) == "table", "AI buildResult must be a table")
	return buildResult.AssignmentDefaults
end

--[=[
	Returns a compact assignment description for one actor resolution request.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@param actorType string
	@param options TResolveBehaviorOptions?
	@return TAssignmentResult
]=]
function AI.DescribeAssignment(
	buildResult: TSystemBuildResult,
	actorType: string,
	options: TResolveBehaviorOptions?
): TAssignmentResult
	return AI.ResolveActorAssignment(buildResult, actorType, options)
end

--[=[
	Returns a compact diagnostic description of one built AI package.
	@within AIEntry
	@param buildResult TSystemBuildResult
	@return { [string]: any }
]=]
function AI.DescribeBuild(buildResult: TSystemBuildResult): { [string]: any }
	assert(type(buildResult) == "table", "AI buildResult must be a table")

	return table.freeze({
		Manifest = buildResult.Manifest,
		Diagnostics = buildResult.Diagnostics,
		AssignmentDefaults = buildResult.AssignmentDefaults,
	})
end

return table.freeze(AI)
