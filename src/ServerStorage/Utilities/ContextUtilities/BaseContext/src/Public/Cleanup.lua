--!strict

--[=[
    @class Cleanup
    Owns tracked cleanup registration and teardown execution for the wrapped service.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Assertions = require(script.Parent.Parent.Internal.Assertions)
local CleanupRunner = require(script.Parent.Parent.Internal.CleanupRunner)
local ServiceAccess = require(script.Parent.Parent.Internal.ServiceAccess)
local Validation = require(script.Parent.Parent.Validation)

local CleanupMethods = {}

local Ok = Result.Ok
local ErrorTypes = table.freeze({
	CleanupFailed = "CleanupFailed",
	TeardownAfterFailed = "TeardownAfterFailed",
	TeardownBeforeFailed = "TeardownBeforeFailed",
	TeardownFieldsFailed = "TeardownFieldsFailed",
	TeardownValidationFailed = "TeardownValidationFailed",
})

local function ToBooleanResult(result: Result.Result<any>): Result.Result<boolean>
	return result:andThen(function()
		return Ok(true)
	end)
end

-- Accumulates cleanup outcomes so the final teardown result can report all failures.
local function AppendCleanupResult(context: any, result: Result.Result<any>)
	local cleanupResults = context._cleanupResults
	if cleanupResults ~= nil then
		table.insert(cleanupResults, result)
	end
end

-- Runs a tracked cleanup task and annotates failures with the cleanup label.
local function RunCleanupTask(context: any, label: string, cleanupCallback: () -> ())
	AppendCleanupResult(context, Result.fromPcall(ErrorTypes.CleanupFailed, cleanupCallback):mapError(function(err)
		return Result.Err(err.type, err.message, {
			label = label,
		})
	end))
end

local function GetHookErrorType(label: string): string
	if label == "Teardown.Before" then
		return ErrorTypes.TeardownBeforeFailed
	end

	return ErrorTypes.TeardownAfterFailed
end

-- Invokes a lifecycle hook only when it exists and converts the result to a boolean success flag.
local function RunLifecycleHook(context: any, hook: any?, label: string): Result.Result<boolean>
	if hook == nil then
		return Ok(true)
	end

	return ToBooleanResult(Result.fromPcall(GetHookErrorType(label), ServiceAccess.CallServiceHook, context, hook, label))
end

-- Registers a cleanup task for an arbitrary resource.
--[=[
    Registers a resource cleanup task with the context janitor.
    @within Cleanup
    @param resource any -- Resource to clean up later.
    @param cleanupMethod string? -- Optional cleanup method override.
    @return any -- The same resource, for call-site chaining.
    @error string -- Raised when the cleanup method is invalid.
]=]
function CleanupMethods:AddCleanup(resource: any, cleanupMethod: string?)
	assert(resource ~= nil, "BaseContext:AddCleanup requires a resource")
	Assertions.AssertOptionalNonEmptyString(cleanupMethod, "BaseContext:AddCleanup cleanupMethod")

	self._janitor:Add(function()
		RunCleanupTask(self, "resource", function()
			CleanupRunner.CleanupResource(resource, cleanupMethod)
		end)
	end, true)

	return resource
end

-- Registers a cleanup task for a tracked service field.
--[=[
    Registers cleanup for a named service field.
    @within Cleanup
    @param fieldName string -- Service field to clean up.
    @param cleanupMethod string? -- Optional cleanup method override.
    @error string -- Raised when the field name is invalid.
]=]
function CleanupMethods:AddCleanupField(fieldName: string, cleanupMethod: string?)
	Assertions.AssertNonEmptyString(fieldName, "BaseContext:AddCleanupField fieldName")
	Assertions.AssertOptionalNonEmptyString(cleanupMethod, "BaseContext:AddCleanupField cleanupMethod")

	self._janitor:Add(function()
		RunCleanupTask(self, fieldName, function()
			CleanupRunner.CleanupField(self, fieldName, cleanupMethod)
		end)
	end, true)
end

-- Flushes the janitor and returns whether every cleanup succeeded.
--[=[
    Runs all registered cleanup tasks.
    @within Cleanup
    @return Result<boolean> -- `true` when cleanup succeeds.
]=]
function CleanupMethods:Cleanup(): Result.Result<boolean>
	self._cleanupResults = {}
	self._janitor:Cleanup()

	local cleanupResult = ToBooleanResult(Result.TryAll(table.unpack(self._cleanupResults)))
	self._cleanupResults = nil
	return cleanupResult
end

-- Registers teardown field cleanups from validated teardown config.
--[=[
    Registers teardown field cleanup specs.
    @within Cleanup
    @param fields any? -- Teardown field specifications.
]=]
function CleanupMethods:RegisterTeardownFields(fields: any?)
	if fields == nil then
		return
	end

	for _, spec in ipairs(fields) do
		self:AddCleanupField(spec.Field, spec.Method)
	end
end

-- Runs teardown hooks, field cleanup, and registered cleanup tasks once.
--[=[
    Destroys the context after running teardown hooks and cleanup tasks.
    @within Cleanup
    @return Result<boolean> -- `true` when teardown succeeds.
]=]
function CleanupMethods:Destroy(): Result.Result<boolean>
	if self._destroyed then
		return Ok(true)
	end

	self._destroyed = true

	local teardown = self._service.Teardown
	if teardown == nil then
		return self:Cleanup()
	end

	-- Validate the teardown contract before any lifecycle work starts.
	local validationResult = ToBooleanResult(
		Result.fromPcall(ErrorTypes.TeardownValidationFailed, Validation.ValidateTeardownRuntime, self, teardown)
	)
	-- Run teardown hooks and field cleanup in the configured order.
	local beforeResult = RunLifecycleHook(self, teardown.Before, "Teardown.Before")
	local fieldsResult = ToBooleanResult(
		Result.fromPcall(ErrorTypes.TeardownFieldsFailed, self.RegisterTeardownFields, self, teardown.Fields)
	)
	local cleanupResult = self:Cleanup()
	local afterResult = RunLifecycleHook(self, teardown.After, "Teardown.After")

	return ToBooleanResult(Result.TryAll(validationResult, beforeResult, fieldsResult, cleanupResult, afterResult))
end

return CleanupMethods
