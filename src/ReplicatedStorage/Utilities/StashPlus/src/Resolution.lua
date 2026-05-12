--!strict

local Types = require(script.Parent.Types)

type TCleanupMethod = Types.TCleanupMethod

local DEFAULT_METHOD_ORDER = table.freeze({
	"Cleanup",
	"Destroy",
	"Disconnect",
	"Cancel",
})

local Resolution = {}

local function _ValidateResolvedMethod(resource: any, resolvedMethod: TCleanupMethod): (boolean, string?)
	if resolvedMethod == true then
		local luaType = type(resource)
		if luaType == "function" or luaType == "thread" then
			return true
		end

		return false, "StashPlus boolean cleanup only supports functions and threads"
	end

	local cleanupFunction = (resource :: any)[resolvedMethod]
	if type(cleanupFunction) == "function" then
		return true
	end

	return false, string.format("StashPlus missing cleanup method '%s'", resolvedMethod)
end

local function _ResolveDynamicMethod(resource: any): TCleanupMethod
	local resourceType = typeof(resource)
	if resourceType == "RBXScriptConnection" then
		return "Disconnect"
	end

	local luaType = type(resource)
	if luaType == "function" or luaType == "thread" then
		return true
	end

	if resourceType == "Instance" then
		return "Destroy"
	end

	if luaType == "table" or luaType == "userdata" then
		for _, methodName in ipairs(DEFAULT_METHOD_ORDER) do
			if type((resource :: any)[methodName]) == "function" then
				return methodName
			end
		end
	end

	return "Destroy"
end

function Resolution.ResolveMethod(resource: any, cleanupMethod: TCleanupMethod?): TCleanupMethod
	if cleanupMethod ~= nil then
		return cleanupMethod
	end

	return _ResolveDynamicMethod(resource)
end

function Resolution.CanCleanup(resource: any, cleanupMethod: TCleanupMethod?): (boolean, string?)
	if resource == nil then
		return false, "StashPlus cleanup resource must not be nil"
	end

	local resolvedMethod = Resolution.ResolveMethod(resource, cleanupMethod)
	return _ValidateResolvedMethod(resource, resolvedMethod)
end

function Resolution.CleanupResource(resource: any, cleanupMethod: TCleanupMethod?): TCleanupMethod
	assert(resource ~= nil, "StashPlus cleanup resource must not be nil")

	local resolvedMethod = Resolution.ResolveMethod(resource, cleanupMethod)
	local canCleanup, errorMessage = _ValidateResolvedMethod(resource, resolvedMethod)
	assert(canCleanup, errorMessage)

	if resolvedMethod == true then
		local luaType = type(resource)
		if luaType == "function" then
			(resource :: () -> ())()
			return resolvedMethod
		end

		assert(luaType == "thread", "StashPlus boolean cleanup only supports functions and threads")
		if coroutine.running() ~= resource then
			task.cancel(resource)
			return resolvedMethod
		end

		task.defer(function()
			task.cancel(resource)
		end)
		return resolvedMethod
	end

	local cleanupFunction = (resource :: any)[resolvedMethod]
	cleanupFunction(resource)
	return resolvedMethod
end

return table.freeze(Resolution)
