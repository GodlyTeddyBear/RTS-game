--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameEvents = require(ReplicatedStorage.Events.GameEvents)

--[=[
    @class BaseApplication
    Shared application base that resolves registry dependencies and game event
    names for derived commands and queries.
]=]

--[=[
    Field-to-registry dependency map used by resolver helpers.
    @within BaseApplication
    @type TDependencyMap { [string]: string }
]=]
export type TDependencyMap = { [string]: string }

export type TBaseApplication = typeof(setmetatable({} :: {
	_contextName: string,
	_operationName: string,
}, {} :: any))

local BaseApplication = {}
BaseApplication.__index = BaseApplication

--[=[
    Creates a new application base for a context and operation pair.
    @within BaseApplication
    @param contextName string -- Owning context label used in diagnostics.
    @param operationName string -- Operation label used in diagnostics.
    @return TBaseApplication -- Base application instance.
]=]
function BaseApplication.new(contextName: string, operationName: string): TBaseApplication
	assert(type(contextName) == "string" and contextName ~= "", "BaseApplication contextName must be a non-empty string")
	assert(type(operationName) == "string" and operationName ~= "", "BaseApplication operationName must be a non-empty string")

	local self = setmetatable({}, BaseApplication)

	self._contextName = contextName
	self._operationName = operationName

	return self
end

function BaseApplication:_Label(): string
	return ("%s:%s"):format(self._contextName, self._operationName)
end

--[=[
    Resolves a single dependency from the registry and stores it on the base instance.
    @within BaseApplication
    @param registry any -- Registry that exposes `Get`.
    @param fieldName string -- Instance field that receives the dependency.
    @param registryName string -- Registry key for the dependency.
    @return any -- Resolved dependency.
]=]
function BaseApplication:_RequireDependency(registry: any, fieldName: string, registryName: string): any
	assert(registry ~= nil, ("%s missing registry"):format(self:_Label()))
	assert(type(fieldName) == "string" and fieldName ~= "", ("%s dependency field must be a non-empty string"):format(self:_Label()))
	assert(type(registryName) == "string" and registryName ~= "", ("%s dependency registry name must be a non-empty string"):format(self:_Label()))

	local dependency = registry:Get(registryName)
	assert(
		dependency ~= nil,
		("%s missing dependency '%s' for field '%s'"):format(self:_Label(), registryName, fieldName)
	)

	self[fieldName] = dependency
	return dependency
end

--[=[
    Resolves every dependency in a field-to-registry map.
    @within BaseApplication
    @param registry any -- Registry that exposes `Get`.
    @param dependencyMap TDependencyMap -- Field names mapped to registry names.
]=]
function BaseApplication:_RequireDependencies(registry: any, dependencyMap: TDependencyMap)
	assert(type(dependencyMap) == "table", ("%s dependency map must be a table"):format(self:_Label()))

	for fieldName, registryName in dependencyMap do
		self:_RequireDependency(registry, fieldName, registryName)
	end
end

--[=[
    Resolves a registered game event name for a context and event pair.
    @within BaseApplication
    @param contextName string -- Game event context name.
    @param eventName string -- Game event name inside the context.
    @return string -- Registered game event identifier.
]=]
function BaseApplication:_GetGameEvent(contextName: string, eventName: string): string
	assert(type(contextName) == "string" and contextName ~= "", ("%s event context must be a non-empty string"):format(self:_Label()))
	assert(type(eventName) == "string" and eventName ~= "", ("%s event name must be a non-empty string"):format(self:_Label()))

	local contextEvents = GameEvents.Events[contextName]
	assert(contextEvents ~= nil, ("%s GameEvent context '%s' is not registered"):format(self:_Label(), contextName))

	local resolvedEventName = contextEvents[eventName]
	assert(resolvedEventName ~= nil, ("%s GameEvent '%s.%s' is not registered"):format(self:_Label(), contextName, eventName))

	return resolvedEventName
end

return BaseApplication
