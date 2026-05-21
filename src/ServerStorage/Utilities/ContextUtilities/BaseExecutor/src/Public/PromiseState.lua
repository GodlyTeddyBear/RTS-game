--!strict

local DEFAULT_PROMISE_TIMEOUT_ERROR = "PromiseTimedOut"

local function _DeepClone(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end

	local tracked = seen
	if tracked == nil then
		tracked = {}
	end

	local existing = tracked[value]
	if existing ~= nil then
		return existing
	end

	local cloned = {}
	tracked[value] = cloned

	for key, nestedValue in pairs(value) do
		cloned[_DeepClone(key, tracked)] = _DeepClone(nestedValue, tracked)
	end

	return cloned
end

local function _DeepFreeze(value: any, seen: { [any]: boolean }?): any
	if type(value) ~= "table" then
		return value
	end

	local tracked = seen
	if tracked == nil then
		tracked = {}
	end

	if tracked[value] == true then
		return value
	end

	tracked[value] = true
	for _, nestedValue in pairs(value) do
		_DeepFreeze(nestedValue, tracked)
	end

	return table.freeze(value)
end

local function _GetEntityPromiseSlots(self: any, entity: number): { [string]: any }?
	return self._promiseState[entity]
end

local function _GetPromiseSlot(self: any, entity: number, key: string): any
	local promiseSlots = _GetEntityPromiseSlots(self, entity)
	if promiseSlots == nil then
		return nil
	end

	return promiseSlots[key]
end

local function _GetOrCreateEntityPromiseSlots(self: any, entity: number): { [string]: any }
	local promiseSlots = self._promiseState[entity]
	if promiseSlots ~= nil then
		return promiseSlots
	end

	promiseSlots = {}
	self._promiseState[entity] = promiseSlots
	return promiseSlots
end

local function _IsActivePromiseSlot(self: any, entity: number, key: string, promiseState: any): boolean
	local currentPromiseState = _GetPromiseSlot(self, entity, key)
	if currentPromiseState ~= promiseState then
		return false
	end

	return self:IsGenerationCurrent(entity, promiseState.Generation)
end

local function _ResolvePromiseStartClock(options: any?): number
	local startedAt = if options ~= nil then options.StartedAt else nil
	if type(startedAt) == "number" then
		return startedAt
	end

	return os.clock()
end

local function _ResolvePromiseTimeoutAt(options: any?, startedAt: number): number?
	if options == nil then
		return nil
	end

	if type(options.TimeoutAt) == "number" then
		return options.TimeoutAt
	end

	if type(options.TimeoutSeconds) == "number" and options.TimeoutSeconds > 0 then
		return startedAt + options.TimeoutSeconds
	end

	return nil
end

local function _ResolvePromiseTimeoutError(options: any?): any
	if options ~= nil and options.TimeoutError ~= nil then
		return options.TimeoutError
	end

	return DEFAULT_PROMISE_TIMEOUT_ERROR
end

return function(BaseExecutor)
	function BaseExecutor:BeginPromise(entity: number, key: string, promise: any, options: any?)
		assert(type(key) == "string" and key ~= "", "BaseExecutor:BeginPromise requires a non-empty key")
		assert(type(promise) == "table", "BaseExecutor:BeginPromise requires a Promise table")
		assert(
			type(promise.andThen) == "function" and type(promise.catch) == "function",
			"BaseExecutor:BeginPromise requires a Promise with :andThen() and :catch()"
		)

		self:ClearPromise(entity, key, true)

		local startedAt = _ResolvePromiseStartClock(options)
		local promiseState = {
			Promise = promise,
			Generation = self:CaptureEntityGeneration(entity),
			Status = "Pending",
			Result = nil,
			Error = nil,
			StartedAt = startedAt,
			TimeoutAt = _ResolvePromiseTimeoutAt(options, startedAt),
			TimeoutError = _ResolvePromiseTimeoutError(options),
		}

		local promiseSlots = _GetOrCreateEntityPromiseSlots(self, entity)
		promiseSlots[key] = promiseState
		self:TrackAsyncResource(entity, key, promise, "cancel")

		promise:andThen(function(result: any)
			if not _IsActivePromiseSlot(self, entity, key, promiseState) then
				return result
			end

			promiseState.Status = "Resolved"
			promiseState.Result = result
			promiseState.Error = nil
			return result
		end):catch(function(err: any)
			if not _IsActivePromiseSlot(self, entity, key, promiseState) then
				return
			end

			promiseState.Status = "Rejected"
			promiseState.Result = nil
			promiseState.Error = err
		end)

		return promiseState
	end

	function BaseExecutor:GetPromiseState(entity: number, key: string): any
		return _GetPromiseSlot(self, entity, key)
	end

	function BaseExecutor:GetPromiseSnapshot(entity: number, key: string): any
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return nil
		end

		return _DeepFreeze(_DeepClone(promiseState))
	end

	function BaseExecutor:GetPromiseStatus(entity: number, key: string): string
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return "Missing"
		end

		return promiseState.Status
	end

	function BaseExecutor:GetPromiseResult(entity: number, key: string): any
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return nil
		end

		return promiseState.Result
	end

	function BaseExecutor:GetPromiseError(entity: number, key: string): any
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return nil
		end

		return promiseState.Error
	end

	function BaseExecutor:HasPendingPromise(entity: number, key: string): boolean
		return self:GetPromiseStatus(entity, key) == "Pending"
	end

	function BaseExecutor:HasResolvedPromise(entity: number, key: string): boolean
		return self:GetPromiseStatus(entity, key) == "Resolved"
	end

	function BaseExecutor:HasRejectedPromise(entity: number, key: string): boolean
		return self:GetPromiseStatus(entity, key) == "Rejected"
	end

	function BaseExecutor:ConsumePromiseResult(entity: number, key: string, shouldClear: boolean?): any
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil or promiseState.Status ~= "Resolved" then
			return nil
		end

		local result = promiseState.Result
		if shouldClear ~= false then
			self:ClearPromise(entity, key, false)
		end

		return result
	end

	function BaseExecutor:ConsumePromiseError(entity: number, key: string, shouldClear: boolean?): any
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil or promiseState.Status ~= "Rejected" then
			return nil
		end

		local err = promiseState.Error
		if shouldClear ~= false then
			self:ClearPromise(entity, key, false)
		end

		return err
	end

	function BaseExecutor:CancelPromise(entity: number, key: string)
		local promiseSlots = _GetEntityPromiseSlots(self, entity)
		if promiseSlots == nil then
			return
		end

		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return
		end

		promiseState.Status = "Cancelled"
		promiseState.Result = nil
		promiseState.Error = nil
		self:ReleaseAsyncResource(entity, key, true)

		promiseSlots[key] = nil
		if next(promiseSlots) == nil then
			self._promiseState[entity] = nil
		end
	end

	function BaseExecutor:ClearPromise(entity: number, key: string, shouldCancel: boolean?)
		local promiseSlots = _GetEntityPromiseSlots(self, entity)
		if promiseSlots == nil then
			return
		end

		if shouldCancel ~= false then
			self:CancelPromise(entity, key)
		else
			self:ReleaseAsyncResource(entity, key, false)
			promiseSlots[key] = nil
			if next(promiseSlots) == nil then
				self._promiseState[entity] = nil
			end
		end
	end

	function BaseExecutor:ClearAllPromises(entity: number, shouldCancel: boolean?)
		local promiseSlots = _GetEntityPromiseSlots(self, entity)
		if promiseSlots == nil then
			return
		end

		local promiseKeys = {}
		for key in pairs(promiseSlots) do
			table.insert(promiseKeys, key)
		end

		for _, key in ipairs(promiseKeys) do
			self:ClearPromise(entity, key, shouldCancel)
		end
	end

	function BaseExecutor:PollPromise(entity: number, key: string): string
		local promiseState = _GetPromiseSlot(self, entity, key)
		if promiseState == nil then
			return "Missing"
		end

		if promiseState.Status ~= "Pending" then
			return promiseState.Status
		end

		if type(promiseState.TimeoutAt) == "number" and os.clock() >= promiseState.TimeoutAt then
			promiseState.Status = "Rejected"
			promiseState.Error = promiseState.TimeoutError
			promiseState.Result = nil
			self:ReleaseAsyncResource(entity, key, true)
		end

		return promiseState.Status
	end
end
