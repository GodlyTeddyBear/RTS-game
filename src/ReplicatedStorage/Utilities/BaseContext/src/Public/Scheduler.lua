--!strict

--[=[
    @class Scheduler
    Registers server scheduler callbacks against the shared `ServerScheduler`.
    @server
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local Config = require(script.Parent.Parent.Internal.Config)
local MethodResolver = require(script.Parent.Parent.Internal.MethodResolver)

local SchedulerMethods = {}

--[=[
	Registers a custom server scheduler callback.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param callback () -> () -- Function called by the scheduler.
]=]
function SchedulerMethods:RegisterSchedulerSystem(phaseName: string, callback: () -> ())
	Assertions.AssertNonEmptyString(phaseName, "BaseContext scheduler phaseName")
	Assertions.AssertFunction(callback, "BaseContext scheduler callback")

	ServerScheduler:RegisterSystem(callback, phaseName)
end

--[=[
	Registers a scheduler system that calls one method on a cached service field.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param targetField string -- Service field containing the target object.
	@param methodName string -- Method name to call on the target object.
]=]
function SchedulerMethods:RegisterMethodSystem(phaseName: string, targetField: string, methodName: string)
	Assertions.AssertNonEmptyString(phaseName, "BaseContext scheduler phaseName")
	local target, method = MethodResolver.ResolveTargetMethod(self, targetField, methodName, "scheduler")

	self:RegisterSchedulerSystem(phaseName, function()
		method(target)
	end)
end

--[=[
	Registers a scheduler system that calls the cached poll method on a service field.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param targetField string -- Service field containing the target object.
	@param methodName string? -- Optional poll method name override.
]=]
function SchedulerMethods:RegisterPollSystem(targetField: string, methodName: string?, phaseName: string)
	self:RegisterMethodSystem(phaseName, targetField, MethodResolver.ResolveMethodName(methodName, Config.DefaultPollMethod, "BaseContext scheduler methodName"))
end

--[=[
	Registers a scheduler system that calls the cached tick method on a service field.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param targetField string -- Service field containing the target object.
	@param methodName string? -- Optional tick method name override.
]=]
function SchedulerMethods:RegisterTickSystem(targetField: string, methodName: string?, phaseName: string)
	self:RegisterMethodSystem(phaseName, targetField, MethodResolver.ResolveMethodName(methodName, Config.DefaultTickMethod, "BaseContext scheduler methodName"))
end

--[=[
	Registers a scheduler system that calls the cached tick method with delta time.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param targetField string -- Service field containing the target object.
	@param methodName string? -- Optional tick method name override.
]=]
function SchedulerMethods:RegisterDeltaTickSystem(targetField: string, methodName: string?, phaseName: string)
	Assertions.AssertNonEmptyString(phaseName, "BaseContext scheduler phaseName")

	local resolvedMethodName = MethodResolver.ResolveMethodName(methodName, Config.DefaultTickMethod, "BaseContext scheduler methodName")
	local target, method = MethodResolver.ResolveTargetMethod(self, targetField, resolvedMethodName, "scheduler")

	self:RegisterSchedulerSystem(phaseName, function()
		method(target, ServerScheduler:GetDeltaTime())
	end)
end

--[=[
	Registers a scheduler system that calls the cached sync method on a service field.
	@within Scheduler
	@param phaseName string -- Server scheduler phase name.
	@param targetField string -- Service field containing the target object.
	@param methodName string? -- Optional sync method name override.
]=]
function SchedulerMethods:RegisterSyncSystem(targetField: string, methodName: string?, phaseName: string)
	self:RegisterMethodSystem(phaseName, targetField, MethodResolver.ResolveMethodName(methodName, Config.DefaultSyncMethod, "BaseContext scheduler methodName"))
end

--[=[
	Returns the server scheduler delta time for custom scheduler callbacks.
	@within Scheduler
	@return number -- Current scheduler delta time.
]=]
function SchedulerMethods:GetSchedulerDeltaTime(): number
	return ServerScheduler:GetDeltaTime()
end

return SchedulerMethods
