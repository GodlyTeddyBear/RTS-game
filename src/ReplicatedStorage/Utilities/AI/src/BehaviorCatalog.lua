--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TBehaviorCatalog = Types.TBehaviorCatalog
type TBehaviorCatalogConfig = Types.TBehaviorCatalogConfig
type TBehaviorCatalogResolved = Types.TBehaviorCatalogResolved
type TRegisterableRuntime = Types.TRegisterableRuntime
type TResolveBehaviorOptions = Types.TResolveBehaviorOptions

--[=[
	@class AIBehaviorCatalog
	Collects named behaviors, aliases, and default assignments before resolving them into a frozen catalog.
	@server
	@client
]=]

local BehaviorCatalog = {}
BehaviorCatalog.__index = BehaviorCatalog

local CATALOG_TRANSITIONS = table.freeze({
	Collect = {
		Resolved = true,
		Disposed = true,
	},
	Resolved = {
		Disposed = true,
	},
	Disposed = {},
})

-- Small helpers keep the catalog phases explicit and keep the collect/resolve flow easy to skim.
local function _GetSortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function _RequireState(catalog: any, expectedState: string, methodName: string)
	local currentState = catalog._lifecycle:GetState()
	assert(currentState == expectedState, ("AI BehaviorCatalog:%s is only legal in state '%s' (current '%s')"):format(methodName, expectedState, currentState))
end

local function _Transition(catalog: any, nextState: string)
	local result = catalog._lifecycle:Transition(nextState)
	assert(result.success, ("AI BehaviorCatalog transition failed: %s"):format(result.message))
end

local function _ResolveAlias(catalog: any, behaviorName: string?): string?
	if behaviorName == nil then
		return nil
	end

	local aliases = catalog._aliases
	return aliases[behaviorName] or behaviorName
end

local function _BuildBehaviors(runtime: TRegisterableRuntime, behaviorDefinitions: { [string]: any }): { [string]: any }
	local builtBehaviors = {}

	for _, name in ipairs(_GetSortedKeys(behaviorDefinitions)) do
		builtBehaviors[name] = runtime:BuildTree(behaviorDefinitions[name])
	end

	return table.freeze(builtBehaviors)
end

--[=[
	Creates a behavior catalog from optional behavior, alias, and default assignments.
	@within AIBehaviorCatalog
	@param config TBehaviorCatalogConfig?
	@return TBehaviorCatalog
]=]
function BehaviorCatalog.new(config: TBehaviorCatalogConfig?): TBehaviorCatalog
	local self = setmetatable({}, BehaviorCatalog)
	self._definitions = {}
	self._aliases = {}
	self._actorDefaults = {}
	self._archetypeDefaults = {}
	self._fallbackBehaviorName = nil
	self._resolved = nil
	self._lifecycle = StateMachine.new({
		InitialState = "Collect",
		Transitions = CATALOG_TRANSITIONS,
		ErrorType = "AIBehaviorCatalogIllegalTransition",
		ErrorMessage = "BehaviorCatalog transition is not allowed",
	})

	if config ~= nil then
		Validation.ValidateBehaviorCatalogConfig(config)

		if config.Behaviors ~= nil then
			for _, name in ipairs(_GetSortedKeys(config.Behaviors)) do
				self._definitions[name] = config.Behaviors[name]
			end
		end

		if config.Aliases ~= nil then
			for _, aliasName in ipairs(_GetSortedKeys(config.Aliases)) do
				self._aliases[aliasName] = config.Aliases[aliasName]
			end
		end

		if config.ActorDefaults ~= nil then
			for _, actorType in ipairs(_GetSortedKeys(config.ActorDefaults)) do
				self._actorDefaults[actorType] = config.ActorDefaults[actorType]
			end
		end

		if config.ArchetypeDefaults ~= nil then
			for _, archetypeName in ipairs(_GetSortedKeys(config.ArchetypeDefaults)) do
				self._archetypeDefaults[archetypeName] = config.ArchetypeDefaults[archetypeName]
			end
		end

		self._fallbackBehaviorName = config.FallbackBehaviorName
	end

	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Adds one behavior definition while the catalog is still collecting registrations.
	@within AIBehaviorCatalog
	@param name string
	@param definition any
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:AddBehavior(name: string, definition: any): TBehaviorCatalog
	_RequireState(self, "Collect", "AddBehavior")
	Validation.ValidateBehaviorRegistrationName(name)
	self._definitions[name] = definition
	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Adds many behavior definitions while the catalog is still collecting registrations.
	@within AIBehaviorCatalog
	@param behaviorDefinitions { [string]: any }
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:AddBehaviors(behaviorDefinitions: { [string]: any }): TBehaviorCatalog
	_RequireState(self, "Collect", "AddBehaviors")
	Validation.ValidateBehaviorDefinitions(behaviorDefinitions)

	for _, name in ipairs(_GetSortedKeys(behaviorDefinitions)) do
		self._definitions[name] = behaviorDefinitions[name]
	end

	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Sets one alias that resolves to a named behavior during catalog build.
	@within AIBehaviorCatalog
	@param aliasName string
	@param behaviorName string
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:SetAlias(aliasName: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetAlias")
	Validation.ValidateBehaviorRegistrationName(aliasName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._aliases[aliasName] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Sets the default behavior for one actor type.
	@within AIBehaviorCatalog
	@param actorType string
	@param behaviorName string
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:SetActorDefault(actorType: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetActorDefault")
	Validation.ValidateActorType(actorType)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._actorDefaults[actorType] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Sets the default behavior for one archetype.
	@within AIBehaviorCatalog
	@param archetypeName string
	@param behaviorName string
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:SetArchetypeDefault(archetypeName: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetArchetypeDefault")
	Validation.ValidateArchetypeName(archetypeName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._archetypeDefaults[archetypeName] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Sets the fallback behavior used when no explicit or default assignment resolves.
	@within AIBehaviorCatalog
	@param behaviorName string
	@return TBehaviorCatalog
]=]
function BehaviorCatalog:SetFallbackBehavior(behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetFallbackBehavior")
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._fallbackBehaviorName = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

--[=[
	Builds and freezes the resolved catalog against the supplied runtime.
	@within AIBehaviorCatalog
	@param runtime TRegisterableRuntime
	@return TBehaviorCatalogResolved
]=]
function BehaviorCatalog:Build(runtime: TRegisterableRuntime): TBehaviorCatalogResolved
	_RequireState(self, "Collect", "Build")
	Validation.ValidateRuntime(runtime)

	-- Build freezes the resolved catalog so assignment lookups stay read-only after construction.
	self._resolved = table.freeze({
		Behaviors = _BuildBehaviors(runtime, self._definitions),
		Aliases = table.freeze(table.clone(self._aliases)),
		ActorDefaults = table.freeze(table.clone(self._actorDefaults)),
		ArchetypeDefaults = table.freeze(table.clone(self._archetypeDefaults)),
		FallbackBehaviorName = self._fallbackBehaviorName,
	})

	_Transition(self, "Resolved")

	return self._resolved
end

--[=[
	Returns one resolved behavior by name or alias.
	@within AIBehaviorCatalog
	@param name string
	@return any?
]=]
function BehaviorCatalog:GetBehavior(name: string): any?
	_RequireState(self, "Resolved", "GetBehavior")
	Validation.ValidateBehaviorRegistrationName(name)

	local resolved = (self :: any)._resolved :: TBehaviorCatalogResolved
	local resolvedName = _ResolveAlias(self, name)

	if resolvedName == nil then
		return nil
	end

	return resolved.Behaviors[resolvedName]
end

--[=[
	Resolves one behavior tree for an actor type using the catalog's assignment order.
	@within AIBehaviorCatalog
	@param actorType string
	@param options TResolveBehaviorOptions?
	@return any?
]=]
function BehaviorCatalog:ResolveForActor(actorType: string, options: TResolveBehaviorOptions?): any?
	_RequireState(self, "Resolved", "ResolveForActor")
	Validation.ValidateActorType(actorType)

	local resolved = (self :: any)._resolved :: TBehaviorCatalogResolved
	-- The resolution order mirrors the builder defaults: explicit input, actor default, archetype default, fallback.
	local behaviorName = if options ~= nil and options.BehaviorName ~= nil
		then options.BehaviorName
		else resolved.ActorDefaults[actorType]

	if behaviorName == nil and options ~= nil and options.ArchetypeName ~= nil then
		Validation.ValidateArchetypeName(options.ArchetypeName)
		behaviorName = resolved.ArchetypeDefaults[options.ArchetypeName]
	end

	if behaviorName == nil then
		behaviorName = resolved.FallbackBehaviorName
	end

	local resolvedName = _ResolveAlias(self, behaviorName)
	if resolvedName == nil then
		return nil
	end

	return resolved.Behaviors[resolvedName]
end

--[=[
	Returns the catalog lifecycle state.
	@within AIBehaviorCatalog
	@return string
]=]
function BehaviorCatalog:GetState(): string
	return self._lifecycle:GetState()
end

--[=[
	Disposes the catalog lifecycle and releases state-machine resources.
	@within AIBehaviorCatalog
]=]
function BehaviorCatalog:Dispose()
	local currentState = self._lifecycle:GetState()
	if currentState ~= "Disposed" then
		local nextState = if currentState == "Collect" then "Disposed" else "Disposed"
		local result = self._lifecycle:Transition(nextState)
		assert(result.success, ("AI BehaviorCatalog transition failed: %s"):format(result.message))
	end

	self._lifecycle:Destroy()
end

return table.freeze({
	new = BehaviorCatalog.new,
	BuildBehaviors = _BuildBehaviors,
})
