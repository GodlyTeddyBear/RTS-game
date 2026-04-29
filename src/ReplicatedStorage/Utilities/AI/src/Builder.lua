--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Utilities.Loader)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local BehaviorCatalog = require(script.Parent.BehaviorCatalog)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TActionPack = Types.TActionPack
type TActorRegistration = Types.TActorRegistration
type TActorBundle = Types.TActorBundle
type TActorPackage = Types.TActorPackage
type TAssignmentDefaults = Types.TAssignmentDefaults
type TSetupDefaults = Types.TSetupDefaults
type TBehaviorCatalogResolved = Types.TBehaviorCatalogResolved
type TSystemBuildResult = Types.TSystemBuildResult
type TSystemBuilder = Types.TSystemBuilder
type TSystemConfig = Types.TSystemConfig
type TRegisterableRuntime = Types.TRegisterableRuntime

--[=[
	@class AISystemBuilder
	Collects AI runtime registrations, behavior definitions, and builder-local defaults before producing one frozen build result.
	@server
	@client
]=]

local Builder = {}
Builder.__index = Builder

local BUILDER_TRANSITIONS = table.freeze({
	Collect = {
		Built = true,
		Disposed = true,
	},
	Built = {
		Disposed = true,
	},
	Disposed = {},
})

-- Small utility helpers keep the build phases easy to read without duplicating table-shape code.
local function _GetSortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function _AppendHooks(target: { any }, hooks: { any })
	for _, hook in ipairs(hooks) do
		table.insert(target, hook)
	end
end

local function _FreezeActionPack(actionPack: TActionPack): TActionPack
	return table.freeze({
		Name = actionPack.Name,
		Definitions = table.freeze(table.clone(actionPack.Definitions)),
	})
end

local function _CloneStringMap(map: { [string]: string }): { [string]: string }
	return table.freeze(table.clone(map))
end

local function _TransitionLifecycle(self: any, nextState: string)
	local result = self._lifecycle:Transition(nextState)
	assert(result.success, ("AI builder transition failed: %s"):format(result.message))
end

local function _AssertCollect(self: any, methodName: string)
	local currentState = self._lifecycle:GetState()
	assert(currentState == "Collect", ("AI builder:%s is only legal in state 'Collect' (current '%s')"):format(methodName, currentState))
end

local function _TrackOverwrite(self: any, registrationKindName: string, entryName: string)
	table.insert(self._duplicateOverwrites, ("%s:%s"):format(registrationKindName, entryName))
end

local function _MergeActionDefinitions(
	self: any,
	target: { [string]: any },
	definitions: { [string]: any },
	registrationKindName: string
)
	for _, actionId in ipairs(_GetSortedKeys(definitions)) do
		if target[actionId] ~= nil then
			_TrackOverwrite(self, registrationKindName, actionId)
		end

		target[actionId] = definitions[actionId]
	end
end

local function _MergeBehaviorDefinitions(self: any, definitions: { [string]: any })
	for _, name in ipairs(_GetSortedKeys(definitions)) do
		if self._behaviorDefinitions[name] ~= nil then
			_TrackOverwrite(self, Types.Enums.RegistrationKind.Behavior.Name, name)
		end

		self._behaviorDefinitions[name] = definitions[name]
	end
end

local function _BuildActorDefaults(actorBundles: { TActorBundle }): { [string]: { DefaultBehaviorName: string? } }
	local actorDefaults = {}

	for _, actorBundle in ipairs(actorBundles) do
		if actorBundle.DefaultBehaviorName ~= nil then
			actorDefaults[actorBundle.ActorType] = {
				DefaultBehaviorName = actorBundle.DefaultBehaviorName,
			}
		end
	end

	return table.freeze(actorDefaults)
end

local function _BuildAssignmentDefaults(
	actorBundles: { TActorBundle },
	resolvedCatalog: TBehaviorCatalogResolved
): TAssignmentDefaults
	local actorBundleDefaults = {}

	for _, actorBundle in ipairs(actorBundles) do
		if actorBundle.DefaultBehaviorName ~= nil then
			actorBundleDefaults[actorBundle.ActorType] = actorBundle.DefaultBehaviorName
		end
	end

	return table.freeze({
		ActorBundleDefaults = _CloneStringMap(actorBundleDefaults),
		ActorTypeDefaults = _CloneStringMap(resolvedCatalog.ActorDefaults),
		ArchetypeDefaults = _CloneStringMap(resolvedCatalog.ArchetypeDefaults),
		FallbackBehaviorName = resolvedCatalog.FallbackBehaviorName,
		ResolutionOrder = table.freeze({
			Types.Enums.AssignmentSource.Explicit.Name,
			Types.Enums.AssignmentSource.ActorBundleDefault.Name,
			Types.Enums.AssignmentSource.ActorTypeDefault.Name,
			Types.Enums.AssignmentSource.ArchetypeDefault.Name,
			Types.Enums.AssignmentSource.Fallback.Name,
			Types.Enums.AssignmentSource.Missing.Name,
		}),
	})
end

local function _BuildSetupDefaults(self: any): TSetupDefaults
	return table.freeze({
		DefaultTickInterval = self._defaultTickInterval,
		TickIntervalByActorType = table.freeze(table.clone(self._tickIntervalByActorType)),
		ClearActionStateOnWrite = self._clearActionStateOnSetup,
		InitializeActionStateByActorType = table.freeze(table.clone(self._initializeActionStateByActorType)),
	})
end

local function _ComposeHooks(self: any): { any }
	local hooks = {}
	_AppendHooks(hooks, self._hookLayers.GlobalHooks)
	_AppendHooks(hooks, self._hookLayers.ActorBundleHooks)
	return table.freeze(hooks)
end

local function _BuildCatalog(self: any, runtime: TRegisterableRuntime): TBehaviorCatalogResolved
	local catalog = BehaviorCatalog.new({
		Behaviors = self._behaviorDefinitions,
		Aliases = self._behaviorAliases,
		ActorDefaults = self._catalogActorDefaults,
		ArchetypeDefaults = self._catalogArchetypeDefaults,
		FallbackBehaviorName = self._fallbackBehaviorName,
	})

	local resolved = catalog:Build(runtime)
	catalog:Dispose()

	return resolved
end

local function _BuildManifest(
	self: any,
	resolvedCatalog: TBehaviorCatalogResolved,
	composedHooks: { any }
): Types.TBuildManifest
	local actorTypes = {}
	local actorBundleTypes = {}

	for _, actorRegistration in ipairs(self._actors) do
		table.insert(actorTypes, actorRegistration.ActorType)
	end

	for _, actorBundle in ipairs(self._actorBundles) do
		table.insert(actorBundleTypes, actorBundle.ActorType)
	end

	table.sort(actorTypes)
	table.sort(actorBundleTypes)

	return table.freeze({
		ActorTypes = table.freeze(actorTypes),
		ActorBundleTypes = table.freeze(actorBundleTypes),
		ActionIds = table.freeze(_GetSortedKeys(self._actions)),
		ActionPacks = table.freeze(_GetSortedKeys(self._actionPacks)),
		BehaviorNames = table.freeze(_GetSortedKeys(resolvedCatalog.Behaviors)),
		Aliases = _CloneStringMap(resolvedCatalog.Aliases),
		ActorDefaults = _CloneStringMap(resolvedCatalog.ActorDefaults),
		ArchetypeDefaults = _CloneStringMap(resolvedCatalog.ArchetypeDefaults),
		FallbackBehaviorName = resolvedCatalog.FallbackBehaviorName,
		LoadedHookCount = #composedHooks,
	})
end

local function _BuildDiagnostics(self: any): Types.TBuildDiagnostics
	return table.freeze({
		BuilderState = self._lifecycle:GetState(),
		BuildStage = self._buildStage,
		DuplicateOverwrites = table.freeze(table.clone(self._duplicateOverwrites)),
		Counts = table.freeze({
			[Types.Enums.RegistrationKind.Hook.Name] = #self._hookLayers.GlobalHooks + #self._hookLayers.ActorBundleHooks,
			[Types.Enums.RegistrationKind.Action.Name] = #_GetSortedKeys(self._actions),
			[Types.Enums.RegistrationKind.ActionPack.Name] = #_GetSortedKeys(self._actionPacks),
			[Types.Enums.RegistrationKind.Actor.Name] = #self._actors,
			[Types.Enums.RegistrationKind.ActorBundle.Name] = #self._actorBundles,
			[Types.Enums.RegistrationKind.Behavior.Name] = #_GetSortedKeys(self._behaviorDefinitions),
		}),
	})
end

--[=[
	Creates a system builder for one AI runtime composition flow.
	@within AISystemBuilder
	@param aiModule any
	@param config TSystemConfig
	@return TSystemBuilder
]=]
function Builder.new(aiModule: any, config: TSystemConfig): TSystemBuilder
	Validation.ValidateSystemConfig(config)

	-- Global hooks are accumulated first so builder-added hooks can stay in one merged list.
	local initialGlobalHooks = {}
	if config.Hooks ~= nil then
		_AppendHooks(initialGlobalHooks, config.Hooks)
	end
	if config.GlobalHooks ~= nil then
		_AppendHooks(initialGlobalHooks, config.GlobalHooks)
	end

	local self = setmetatable({}, Builder)
	self._ai = aiModule
	self._config = {
		Conditions = config.Conditions,
		Commands = config.Commands,
		ErrorSink = config.ErrorSink,
	}
	self._hookLayers = {
		GlobalHooks = initialGlobalHooks,
		ActorBundleHooks = {},
	}
	self._actions = {}
	self._actionPacks = {}
	self._actors = {}
	self._actorBundles = {}
	self._behaviorDefinitions = {}
	self._behaviorAliases = {}
	self._catalogActorDefaults = {}
	self._catalogArchetypeDefaults = {}
	self._fallbackBehaviorName = nil
	self._tickIntervalByActorType = {}
	self._defaultTickInterval = nil
	self._clearActionStateOnSetup = nil
	self._initializeActionStateByActorType = {}
	self._buildStage = Types.Enums.BuildStage.Collect.Name
	self._duplicateOverwrites = {}
	self._lifecycle = StateMachine.new({
		InitialState = Types.Enums.BuilderState.Collect.Name,
		Transitions = BUILDER_TRANSITIONS,
		ErrorType = "AIBuilderIllegalTransition",
		ErrorMessage = "AI builder transition is not allowed",
	})

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds hooks to the builder's global hook bucket.
	@within AISystemBuilder
	@param hooks { any }
	@return TSystemBuilder
]=]
function Builder:AddHooks(hooks: { any }): TSystemBuilder
	_AssertCollect(self, "AddHooks")
	Validation.ValidateHooks(hooks)
	_AppendHooks(self._hookLayers.GlobalHooks, hooks)
	return (self :: any) :: TSystemBuilder
end

--[=[
	Loads hook modules from one folder into the builder's global hook bucket.
	@within AISystemBuilder
	@param folder Instance
	@param predicate ((ModuleScript) -> boolean)?
	@return TSystemBuilder
]=]
function Builder:LoadHooks(folder: Instance, predicate: ((ModuleScript) -> boolean)?): TSystemBuilder
	_AssertCollect(self, "LoadHooks")
	Validation.ValidateFolder(folder, Types.Enums.RegistrationKind.Hook.Name)
	local loadedHooks = Loader.LoadChildren(folder, predicate)

	for _, moduleName in ipairs(_GetSortedKeys(loadedHooks)) do
		table.insert(self._hookLayers.GlobalHooks, loadedHooks[moduleName])
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds many action definitions to the builder's action registry.
	@within AISystemBuilder
	@param actionDefinitions { [string]: any }
	@return TSystemBuilder
]=]
function Builder:AddActions(actionDefinitions: { [string]: any }): TSystemBuilder
	_AssertCollect(self, "AddActions")
	Validation.ValidateActionDefinitions(actionDefinitions)
	_MergeActionDefinitions(self, self._actions, actionDefinitions, Types.Enums.RegistrationKind.Action.Name)
	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds one named action pack and merges its definitions into the builder's action registry.
	@within AISystemBuilder
	@param actionPack TActionPack
	@return TSystemBuilder
]=]
function Builder:AddActionPack(actionPack: TActionPack): TSystemBuilder
	_AssertCollect(self, "AddActionPack")
	Validation.ValidateActionPack(actionPack)

	if self._actionPacks[actionPack.Name] ~= nil then
		_TrackOverwrite(self, Types.Enums.RegistrationKind.ActionPack.Name, actionPack.Name)
	end

	self._actionPacks[actionPack.Name] = _FreezeActionPack(actionPack)
	_MergeActionDefinitions(self, self._actions, actionPack.Definitions, Types.Enums.RegistrationKind.ActionPack.Name)

	return (self :: any) :: TSystemBuilder
end

--[=[
	Loads action definition modules from one folder into the builder's action registry.
	@within AISystemBuilder
	@param folder Instance
	@param predicate ((ModuleScript) -> boolean)?
	@return TSystemBuilder
]=]
function Builder:LoadActions(folder: Instance, predicate: ((ModuleScript) -> boolean)?): TSystemBuilder
	_AssertCollect(self, "LoadActions")
	Validation.ValidateFolder(folder, Types.Enums.RegistrationKind.Action.Name)
	local loadedDefinitions = Loader.LoadChildren(folder, predicate)

	for _, moduleName in ipairs(_GetSortedKeys(loadedDefinitions)) do
		local definitionBundle = loadedDefinitions[moduleName]
		Validation.ValidateActionDefinitions(definitionBundle)
		_MergeActionDefinitions(self, self._actions, definitionBundle, Types.Enums.RegistrationKind.Action.Name)
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds one actor registration to the builder.
	@within AISystemBuilder
	@param registration TActorRegistration
	@return TSystemBuilder
]=]
function Builder:AddActor(registration: TActorRegistration): TSystemBuilder
	_AssertCollect(self, "AddActor")
	Validation.ValidateRegistration(registration)
	table.insert(self._actors, registration)

	if registration.Actions ~= nil then
		Validation.ValidateActionDefinitions(registration.Actions)
		_MergeActionDefinitions(self, self._actions, registration.Actions, Types.Enums.RegistrationKind.Actor.Name)
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds one actor bundle and merges its hook, action-pack, and default metadata.
	@within AISystemBuilder
	@param bundle TActorBundle
	@return TSystemBuilder
]=]
function Builder:AddActorBundle(bundle: TActorBundle): TSystemBuilder
	_AssertCollect(self, "AddActorBundle")
	Validation.ValidateActorBundle(bundle)
	table.insert(self._actorBundles, bundle)

	-- Bundle-local hooks and action packs fold into the shared builder state before the actor registration is flattened.
	if bundle.Hooks ~= nil then
		_AppendHooks(self._hookLayers.ActorBundleHooks, bundle.Hooks)
	end

	if bundle.ActionPacks ~= nil then
		for _, actionPack in ipairs(bundle.ActionPacks) do
			self:AddActionPack(actionPack)
		end
	end

	self:AddActor({
		ActorType = bundle.ActorType,
		Adapter = bundle.Adapter,
		Actions = bundle.Actions,
	})

	if bundle.DefaultBehaviorName ~= nil then
		if self._catalogActorDefaults[bundle.ActorType] ~= nil then
			_TrackOverwrite(self, Types.Enums.RegistrationKind.ActorBundle.Name, bundle.ActorType)
		end

		self._catalogActorDefaults[bundle.ActorType] = bundle.DefaultBehaviorName
	end

	if bundle.TickInterval ~= nil then
		self._tickIntervalByActorType[bundle.ActorType] = bundle.TickInterval
	end

	if bundle.InitializeActionState ~= nil then
		self._initializeActionStateByActorType[bundle.ActorType] = bundle.InitializeActionState
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds many actor bundles in order.
	@within AISystemBuilder
	@param bundles { TActorBundle }
	@return TSystemBuilder
]=]
function Builder:AddActorBundles(bundles: { TActorBundle }): TSystemBuilder
	_AssertCollect(self, "AddActorBundles")
	Validation.ValidateActorBundles(bundles)

	for _, bundle in ipairs(bundles) do
		self:AddActorBundle(bundle)
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds one actor package and merges its package-level defaults into the builder.
	@within AISystemBuilder
	@param actorPackage TActorPackage
	@return TSystemBuilder
]=]
function Builder:AddActorPackage(actorPackage: TActorPackage): TSystemBuilder
	_AssertCollect(self, "AddActorPackage")
	Validation.ValidateActorPackage(actorPackage)

	local actorBundle = actorPackage.ActorBundle
	-- Package-level defaults override the bundle only when the bundle leaves them unset.
	if actorPackage.TickInterval ~= nil or actorPackage.InitializeActionState ~= nil then
		actorBundle = {
			ActorType = actorBundle.ActorType,
			Adapter = actorBundle.Adapter,
			Actions = actorBundle.Actions,
			ActionPacks = actorBundle.ActionPacks,
			DefaultBehaviorName = actorBundle.DefaultBehaviorName,
			Hooks = actorBundle.Hooks,
			TickInterval = if actorBundle.TickInterval ~= nil then actorBundle.TickInterval else actorPackage.TickInterval,
			InitializeActionState = if actorBundle.InitializeActionState ~= nil
				then actorBundle.InitializeActionState
				else actorPackage.InitializeActionState,
		}
	end

	self:AddActorBundle(actorBundle)

	if actorPackage.Behaviors ~= nil then
		self:AddBehaviors(actorPackage.Behaviors)
	end

	if actorPackage.Aliases ~= nil then
		for _, aliasName in ipairs(_GetSortedKeys(actorPackage.Aliases)) do
			self:SetBehaviorAlias(aliasName, actorPackage.Aliases[aliasName])
		end
	end

	if actorPackage.ArchetypeDefaults ~= nil then
		for _, archetypeName in ipairs(_GetSortedKeys(actorPackage.ArchetypeDefaults)) do
			self:SetArchetypeDefault(archetypeName, actorPackage.ArchetypeDefaults[archetypeName])
		end
	end

	if actorPackage.FallbackBehaviorName ~= nil then
		self:SetFallbackBehavior(actorPackage.FallbackBehaviorName)
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds many actor packages in order.
	@within AISystemBuilder
	@param actorPackages { TActorPackage }
	@return TSystemBuilder
]=]
function Builder:AddActorPackages(actorPackages: { TActorPackage }): TSystemBuilder
	_AssertCollect(self, "AddActorPackages")
	Validation.ValidateActorPackages(actorPackages)

	for _, actorPackage in ipairs(actorPackages) do
		self:AddActorPackage(actorPackage)
	end

	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets one behavior alias on the builder catalog.
	@within AISystemBuilder
	@param aliasName string
	@param behaviorName string
	@return TSystemBuilder
]=]
function Builder:SetBehaviorAlias(aliasName: string, behaviorName: string): TSystemBuilder
	_AssertCollect(self, "SetBehaviorAlias")
	Validation.ValidateBehaviorAlias(aliasName, behaviorName)

	if self._behaviorAliases[aliasName] ~= nil then
		_TrackOverwrite(self, Types.Enums.RegistrationKind.Behavior.Name, aliasName)
	end

	self._behaviorAliases[aliasName] = behaviorName
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets one actor-type default behavior on the builder catalog.
	@within AISystemBuilder
	@param actorType string
	@param behaviorName string
	@return TSystemBuilder
]=]
function Builder:SetActorDefault(actorType: string, behaviorName: string): TSystemBuilder
	_AssertCollect(self, "SetActorDefault")
	Validation.ValidateActorType(actorType)
	Validation.ValidateBehaviorRegistrationName(behaviorName)

	if self._catalogActorDefaults[actorType] ~= nil then
		_TrackOverwrite(self, Types.Enums.RegistrationKind.Actor.Name, actorType)
	end

	self._catalogActorDefaults[actorType] = behaviorName
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets one archetype default behavior on the builder catalog.
	@within AISystemBuilder
	@param archetypeName string
	@param behaviorName string
	@return TSystemBuilder
]=]
function Builder:SetArchetypeDefault(archetypeName: string, behaviorName: string): TSystemBuilder
	_AssertCollect(self, "SetArchetypeDefault")
	Validation.ValidateArchetypeName(archetypeName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)

	if self._catalogArchetypeDefaults[archetypeName] ~= nil then
		_TrackOverwrite(self, Types.Enums.RegistrationKind.Behavior.Name, archetypeName)
	end

	self._catalogArchetypeDefaults[archetypeName] = behaviorName
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets the fallback behavior used when no other assignment source resolves.
	@within AISystemBuilder
	@param behaviorName string
	@return TSystemBuilder
]=]
function Builder:SetFallbackBehavior(behaviorName: string): TSystemBuilder
	_AssertCollect(self, "SetFallbackBehavior")
	Validation.ValidateBehaviorRegistrationName(behaviorName)

	if self._fallbackBehaviorName ~= nil then
		_TrackOverwrite(self, Types.Enums.RegistrationKind.Behavior.Name, "__fallback__")
	end

	self._fallbackBehaviorName = behaviorName
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets one actor-type tick interval used while writing actor setups.
	@within AISystemBuilder
	@param actorType string
	@param tickInterval number
	@return TSystemBuilder
]=]
function Builder:SetActorTickInterval(actorType: string, tickInterval: number): TSystemBuilder
	_AssertCollect(self, "SetActorTickInterval")
	Validation.ValidateActorType(actorType)
	Validation.ValidateTickInterval(tickInterval)
	self._tickIntervalByActorType[actorType] = tickInterval
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets the default tick interval used when an actor type does not override it.
	@within AISystemBuilder
	@param tickInterval number
	@return TSystemBuilder
]=]
function Builder:SetDefaultTickInterval(tickInterval: number): TSystemBuilder
	_AssertCollect(self, "SetDefaultTickInterval")
	Validation.ValidateTickInterval(tickInterval)
	self._defaultTickInterval = tickInterval
	return (self :: any) :: TSystemBuilder
end

--[=[
	Sets whether setup writing should clear action state by default.
	@within AISystemBuilder
	@param enabled boolean
	@return TSystemBuilder
]=]
function Builder:SetClearActionStateOnSetup(enabled: boolean): TSystemBuilder
	_AssertCollect(self, "SetClearActionStateOnSetup")
	assert(type(enabled) == "boolean", "AI setup clear flag must be a boolean")
	self._clearActionStateOnSetup = enabled
	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds one named behavior definition to the builder catalog.
	@within AISystemBuilder
	@param name string
	@param definition any
	@return TSystemBuilder
]=]
function Builder:AddBehavior(name: string, definition: any): TSystemBuilder
	_AssertCollect(self, "AddBehavior")
	Validation.ValidateBehaviorRegistrationName(name)
	_MergeBehaviorDefinitions(self, {
		[name] = definition,
	})
	return (self :: any) :: TSystemBuilder
end

--[=[
	Adds many named behavior definitions to the builder catalog.
	@within AISystemBuilder
	@param behaviorDefinitions { [string]: any }
	@return TSystemBuilder
]=]
function Builder:AddBehaviors(behaviorDefinitions: { [string]: any }): TSystemBuilder
	_AssertCollect(self, "AddBehaviors")
	Validation.ValidateBehaviorDefinitions(behaviorDefinitions)
	_MergeBehaviorDefinitions(self, behaviorDefinitions)
	return (self :: any) :: TSystemBuilder
end

--[=[
	Loads behavior definition modules from one folder into the builder catalog.
	@within AISystemBuilder
	@param folder Instance
	@param predicate ((ModuleScript) -> boolean)?
	@return TSystemBuilder
]=]
function Builder:LoadBehaviors(folder: Instance, predicate: ((ModuleScript) -> boolean)?): TSystemBuilder
	_AssertCollect(self, "LoadBehaviors")
	Validation.ValidateFolder(folder, Types.Enums.RegistrationKind.Behavior.Name)
	local loadedDefinitions = Loader.LoadChildren(folder, predicate)
	Validation.ValidateBehaviorDefinitions(loadedDefinitions)
	_MergeBehaviorDefinitions(self, loadedDefinitions)
	return (self :: any) :: TSystemBuilder
end

--[=[
	Returns the builder lifecycle state.
	@within AISystemBuilder
	@return string
]=]
function Builder:GetState(): string
	return self._lifecycle:GetState()
end

--[=[
	Disposes the builder lifecycle and releases its state machine resources.
	@within AISystemBuilder
]=]
function Builder:Dispose()
	local currentState = self._lifecycle:GetState()
	if currentState == Types.Enums.BuilderState.Disposed.Name then
		return
	end

	_TransitionLifecycle(self, Types.Enums.BuilderState.Disposed.Name)
	self._buildStage = Types.Enums.BuildStage.Complete.Name
	self._lifecycle:Destroy()
end

--[=[
	Builds the frozen AI runtime bundle from the collected registrations.
	@within AISystemBuilder
	@return TSystemBuildResult
]=]
function Builder:Build(): TSystemBuildResult
	_AssertCollect(self, "Build")
	-- The builder moves through explicit stages so diagnostics can explain exactly where construction stopped.
	self._buildStage = Types.Enums.BuildStage.RuntimeCreate.Name

	-- Hooks are composed once, then reused for both hook registration aliases on the runtime.
	local composedHooks = _ComposeHooks(self)
	local runtime = self._ai.CreateRuntime({
		Conditions = self._config.Conditions,
		Commands = self._config.Commands,
		Hooks = composedHooks,
		GlobalHooks = composedHooks,
		ErrorSink = self._config.ErrorSink,
	})

	if next(self._actions) ~= nil then
		-- Actions register before actors so actors can rely on the executor set already being present.
		self._buildStage = Types.Enums.BuildStage.RegisterActions.Name
		self._ai.RegisterActions(runtime, self._actions)
	end

	-- Actor adapters register after actions because the runtime is now ready for tree execution.
	self._buildStage = Types.Enums.BuildStage.RegisterActors.Name
	for _, actorRegistration in ipairs(self._actors) do
		self._ai.RegisterActor(runtime, actorRegistration.ActorType, actorRegistration.Adapter)
	end

	-- Behavior compilation is last because it depends on the runtime knowing the executors it can reference.
	self._buildStage = Types.Enums.BuildStage.BuildBehaviors.Name
	local resolvedCatalog = _BuildCatalog(self, runtime)
	local actorDefaults = _BuildActorDefaults(self._actorBundles)
	local assignmentDefaults = _BuildAssignmentDefaults(self._actorBundles, resolvedCatalog)
	local setupDefaults = _BuildSetupDefaults(self)

	_TransitionLifecycle(self, Types.Enums.BuilderState.Built.Name)
	self._buildStage = Types.Enums.BuildStage.Complete.Name

	-- Freeze the final product so downstream code cannot mutate the collected registration snapshot by accident.
	local buildResult = table.freeze({
		Runtime = runtime,
		Behaviors = resolvedCatalog.Behaviors,
		Actors = table.freeze(table.clone(self._actors)),
		Actions = table.freeze(table.clone(self._actions)),
		ActionPacks = table.freeze((function()
			local actionPacks = {}
			for _, name in ipairs(_GetSortedKeys(self._actionPacks)) do
				table.insert(actionPacks, self._actionPacks[name])
			end
			return actionPacks
		end)()),
		ActorBundles = table.freeze(table.clone(self._actorBundles)),
		ActorDefaults = actorDefaults,
		AssignmentDefaults = assignmentDefaults,
		SetupDefaults = setupDefaults,
		Catalog = resolvedCatalog,
		Manifest = _BuildManifest(self, resolvedCatalog, composedHooks),
		Diagnostics = _BuildDiagnostics(self),
	})

	return buildResult
end

return table.freeze({
	new = Builder.new,
	BuildBehaviors = BehaviorCatalog.BuildBehaviors,
	BuildActorDefaults = _BuildActorDefaults,
})
