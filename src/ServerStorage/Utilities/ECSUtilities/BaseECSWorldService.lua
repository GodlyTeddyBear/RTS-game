--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class BaseECSWorldService
	Owns one isolated JECS world per bounded context and exposes the init/reset
	lifecycle used by derived ECS world services.
	@server
]=]
local BaseECSWorldService = {}
BaseECSWorldService.__index = BaseECSWorldService

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
	Creates a new base world service with one JECS world instance.
	@within BaseECSWorldService
	@param contextName string -- Owning context label used in diagnostics and assertions.
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
	Marks the base world service initialized and runs the derived init hook.
	@within BaseECSWorldService
	@param _registry any -- Dependency registry for this context.
	@param _name string -- Registered module name.
]=]
function BaseECSWorldService:Init(_registry: any, _name: string)
	assert(self._world ~= nil, ("%sECSWorldService: missing world"):format(self._contextName))
	if type(self._OnInit) == "function" then
		self:_OnInit(_registry, _name)
	end
	self._initialized = true
end

-- Derived init hook that lets subclasses run setup after the world exists.
function BaseECSWorldService:_OnInit(_registry: any, _name: string)
	return
end

--[=[
	Asserts that `Init()` has completed for this service.
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
	self:AssertInitialized()
	assert(self._world ~= nil, ("%sECSWorldService: missing world"):format(self._contextName))
	return self._world
end

--[=[
	Replaces the current world with a fresh instance and clears initialization state.
	@within BaseECSWorldService
]=]
function BaseECSWorldService:Reset()
	if type(self._OnDestroy) == "function" then
		self:_OnDestroy()
	end

	self._world = JECS.World.new()
	self._initialized = false
end

--[=[
	Runs the destroy hook and marks the service uninitialized.
	@within BaseECSWorldService
]=]
function BaseECSWorldService:Destroy()
	if type(self._OnDestroy) == "function" then
		self:_OnDestroy()
	end

	self._initialized = false
end

-- ── Private ───────────────────────────────────────────────────────────────────

-- Derived teardown hook that lets subclasses release world-scoped state.
function BaseECSWorldService:_OnDestroy()
	return
end

return BaseECSWorldService
