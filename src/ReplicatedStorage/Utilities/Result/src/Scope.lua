--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local ScopeModule = {}

local Core = require(script.Parent.Core)

export type Scope = {
	add: (self: Scope, resource: any, cleanupFn: (resource: any) -> ()) -> (),
	addJanitorItem: (self: Scope, object: any, methodName: (string | boolean)?) -> (),
	addPromise: (self: Scope, promise: any) -> any,
}

type ScopeInternal = Scope & {
	_janitor: any,
}

local function newScope(): Scope
	local scope = setmetatable({
		_janitor = Janitor.new(),
	}, {
		__index = {
			add = function(self: ScopeInternal, resource: any, cleanupFn: (resource: any) -> ())
				self._janitor:Add(function()
					cleanupFn(resource)
				end, true)
			end,

			addJanitorItem = function(self: ScopeInternal, object: any, methodName: (string | boolean)?)
				self._janitor:Add(object, methodName)
			end,

			addPromise = function(self: ScopeInternal, promise: any): any
				return self._janitor:AddPromise(promise)
			end,
		},
	})
	return scope :: any
end

local function flushScope(scope: Scope)
	(scope :: ScopeInternal)._janitor:Cleanup()
end

function ScopeModule.Apply(Result: any)
	--[=[
		Runs a function with a cleanup scope that always flushes on exit.
		@within Result
	]=]
	function Result.scoped(fn: (scope: Scope) -> Core.Result<any>): Core.Result<any>
		local scope = newScope()
		local ok, result = xpcall(fn, function(thrown)
			if type(thrown) == "table" and (thrown :: any)._isResult then
				return thrown
			end
			return Result.Defect(tostring(thrown), debug.traceback(nil, 2))
		end, scope)
		flushScope(scope)
		if not ok then
			return result :: any
		end
		if not Result.isResult(result) then
			return Result.Ok(result)
		end
		return result :: any
	end

	--[=[
		Acquires one resource, uses it, and guarantees release through a scope.
		@within Result
	]=]
	function Result.acquireRelease<T, U>(
		acquire: () -> Core.Result<T>,
		release: (resource: T) -> (),
		use: (resource: T) -> Core.Result<U>
	): Core.Result<U>
		local acquireResult = acquire()
		if not acquireResult.success then
			return acquireResult :: any
		end
		local resource = (acquireResult :: Core.Ok<T>).value
		return Result.scoped(function(scope: Scope)
			scope:add(resource, release)
			return use(resource)
		end)
	end
end

return ScopeModule
