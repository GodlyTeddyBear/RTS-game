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

local function _EnsureRegistrationBucket(self: any, targetField: string): any
	local registrations = self._schedulerRegistrations
	local bucket = registrations[targetField]
	if bucket ~= nil then
		return bucket
	end

	bucket = {
		Poll = {},
		Sync = {},
	}
	registrations[targetField] = bucket
	return bucket
end

local function _RecordRegistration(self: any, targetField: string, registrationKind: "Poll" | "Sync", phaseName: string)
	local bucket = _EnsureRegistrationBucket(self, targetField)
	bucket[registrationKind][phaseName] = true
end

local function _GetSortedPhaseNames(phasesByName: { [string]: boolean }): { string }
	local phaseNames = {}
	for phaseName in phasesByName do
		table.insert(phaseNames, phaseName)
	end
	table.sort(phaseNames)
	return phaseNames
end

local function _BuildMethodStatus(target: any, methodName: string, registeredPhases: { [string]: boolean }): any
	local method = if target ~= nil then target[methodName] else nil
	return table.freeze({
		MethodName = methodName,
		HasMethod = type(method) == "function",
		RegisteredPhases = table.freeze(_GetSortedPhaseNames(registeredPhases)),
	})
end

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
	Poll systems are for services that must sample live runtime state and write it
	back into ECS or another authoritative store. They are not interchangeable
	with sync systems, which only project authoritative state onto instances.
]=]
function SchedulerMethods:RegisterPollSystem(targetField: string, methodName: string?, phaseName: string)
	self:RegisterMethodSystem(phaseName, targetField, MethodResolver.ResolveMethodName(methodName, Config.DefaultPollMethod, "BaseContext scheduler methodName"))
	_RecordRegistration(self, targetField, "Poll", phaseName)
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
	Sync systems are for projection-only services that push authoritative ECS state
	out onto their bound instance. They do not sample runtime state back into ECS.
]=]
function SchedulerMethods:RegisterSyncSystem(targetField: string, methodName: string?, phaseName: string)
	self:RegisterMethodSystem(phaseName, targetField, MethodResolver.ResolveMethodName(methodName, Config.DefaultSyncMethod, "BaseContext scheduler methodName"))
	_RecordRegistration(self, targetField, "Sync", phaseName)
end

--[=[
	Returns scheduler binding status for one cached service field.
	@within Scheduler
	@param targetField string -- Service field containing the target object.
	@return any -- Read-only status describing method surfaces and registered phases.
]=]
function SchedulerMethods:GetSchedulerBindingStatus(targetField: string): any
	Assertions.AssertNonEmptyString(targetField, "BaseContext scheduler targetField")

	local target = self._service[targetField]
	local bucket = self._schedulerRegistrations[targetField]
	local pollPhases = if bucket ~= nil then bucket.Poll else {}
	local syncPhases = if bucket ~= nil then bucket.Sync else {}

	return table.freeze({
		TargetField = targetField,
		TargetExists = target ~= nil,
		Poll = _BuildMethodStatus(target, Config.DefaultPollMethod, pollPhases),
		Sync = _BuildMethodStatus(target, Config.DefaultSyncMethod, syncPhases),
	})
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
