--!strict

--[=[
    @class CleanupRunner
    Internal cleanup helpers that resolve and invoke resource teardown methods.
    @server
]=]

local CleanupRunner = {}

-- Reads the cleanup method through `pcall` so missing metamethods do not break probing.
local function GetCleanupMethod(resource: any, methodName: string): any?
	local success, method = pcall(function()
		return resource[methodName]
	end)

	if not success then
		return nil
	end

	return method
end

-- Prefers `Disconnect` first because tracked connections are the common cleanup shape.
local function ResolveCleanupMethodName(resource: any): string?
	if GetCleanupMethod(resource, "Disconnect") ~= nil then
		return "Disconnect"
	end

	if GetCleanupMethod(resource, "Destroy") ~= nil then
		return "Destroy"
	end

	return nil
end

-- Invokes the resolved cleanup method for a resource and raises when no supported method exists.
--[=[
    Cleans up a resource by calling its `Disconnect` or `Destroy` method.
    @within CleanupRunner
    @param resource any -- Resource to clean up.
    @param cleanupMethod string? -- Optional cleanup method override.
    @error string -- Raised when no supported cleanup method exists or the method is not callable.
]=]
function CleanupRunner.CleanupResource(resource: any, cleanupMethod: string?)
	if resource == nil then
		return
	end

	local methodName = cleanupMethod or ResolveCleanupMethodName(resource)
	assert(methodName ~= nil, "BaseContext cleanup resource must provide Disconnect or Destroy")

	local method = GetCleanupMethod(resource, methodName)
	assert(type(method) == "function", ("BaseContext cleanup method '%s' must be a function"):format(methodName))
	method(resource)
end

-- Looks up a tracked service field and cleans it up using the same resource rules.
--[=[
    Cleans up a tracked service field by name.
    @within CleanupRunner
    @param context any -- BaseContext instance that owns the service table.
    @param fieldName string -- Service field name to clean up.
    @param cleanupMethod string? -- Optional cleanup method override.
    @error string -- Raised when the tracked field cannot be cleaned up.
]=]
function CleanupRunner.CleanupField(context: any, fieldName: string, cleanupMethod: string?)
	CleanupRunner.CleanupResource(context._service[fieldName], cleanupMethod)
end

return table.freeze(CleanupRunner)
