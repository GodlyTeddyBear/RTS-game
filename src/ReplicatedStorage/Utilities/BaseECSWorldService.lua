--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class BaseECSWorldService
	Shared isolated JECS world owner used by bounded ECS contexts.
	@server
]=]
local BaseECSWorldService = {}
BaseECSWorldService.__index = BaseECSWorldService

--[=[
	Creates a new base world service with one JECS world instance.
	@within BaseECSWorldService
	@param contextName string -- The owning context label used in assertions.
	@return BaseECSWorldService -- The base service instance.
]=]
function BaseECSWorldService.new(contextName: string)
	local self = setmetatable({}, BaseECSWorldService)
	self._contextName = contextName
	self._world = JECS.World.new()
	self._initialized = false
	return self
end

--[=[
	Marks the base world service initialized.
	@within BaseECSWorldService
	@param _registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function BaseECSWorldService:Init(_registry: any, _name: string)
	assert(self._world ~= nil, ("%sECSWorldService: missing world"):format(self._contextName))
	self._initialized = true
end

--[=[
	Asserts that Init() has completed for this service.
	@within BaseECSWorldService
]=]
function BaseECSWorldService:AssertInitialized()
	assert(self._initialized, ("%sECSWorldService: used before Init"):format(self._contextName))
end

--[=[
	Returns the owning context label for diagnostics.
	@within BaseECSWorldService
	@return string -- Context name passed to new().
]=]
function BaseECSWorldService:GetContextName(): string
	return self._contextName
end

--[=[
	Returns the isolated JECS world instance.
	@within BaseECSWorldService
	@return any -- The context world.
]=]
function BaseECSWorldService:GetWorld()
	assert(self._world ~= nil, ("%sECSWorldService: missing world"):format(self._contextName))
	return self._world
end

return BaseECSWorldService
