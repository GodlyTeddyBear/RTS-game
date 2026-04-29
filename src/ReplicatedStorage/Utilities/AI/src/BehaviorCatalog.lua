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

function BehaviorCatalog:AddBehavior(name: string, definition: any): TBehaviorCatalog
	_RequireState(self, "Collect", "AddBehavior")
	Validation.ValidateBehaviorRegistrationName(name)
	self._definitions[name] = definition
	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:AddBehaviors(behaviorDefinitions: { [string]: any }): TBehaviorCatalog
	_RequireState(self, "Collect", "AddBehaviors")
	Validation.ValidateBehaviorDefinitions(behaviorDefinitions)

	for _, name in ipairs(_GetSortedKeys(behaviorDefinitions)) do
		self._definitions[name] = behaviorDefinitions[name]
	end

	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:SetAlias(aliasName: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetAlias")
	Validation.ValidateBehaviorRegistrationName(aliasName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._aliases[aliasName] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:SetActorDefault(actorType: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetActorDefault")
	Validation.ValidateActorType(actorType)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._actorDefaults[actorType] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:SetArchetypeDefault(archetypeName: string, behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetArchetypeDefault")
	Validation.ValidateArchetypeName(archetypeName)
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._archetypeDefaults[archetypeName] = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:SetFallbackBehavior(behaviorName: string): TBehaviorCatalog
	_RequireState(self, "Collect", "SetFallbackBehavior")
	Validation.ValidateBehaviorRegistrationName(behaviorName)
	self._fallbackBehaviorName = behaviorName
	return (self :: any) :: TBehaviorCatalog
end

function BehaviorCatalog:Build(runtime: TRegisterableRuntime): TBehaviorCatalogResolved
	_RequireState(self, "Collect", "Build")
	Validation.ValidateRuntime(runtime)

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

function BehaviorCatalog:ResolveForActor(actorType: string, options: TResolveBehaviorOptions?): any?
	_RequireState(self, "Resolved", "ResolveForActor")
	Validation.ValidateActorType(actorType)

	local resolved = (self :: any)._resolved :: TBehaviorCatalogResolved
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

function BehaviorCatalog:GetState(): string
	return self._lifecycle:GetState()
end

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
