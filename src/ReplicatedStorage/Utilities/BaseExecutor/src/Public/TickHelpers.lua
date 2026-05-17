--!strict

local VALID_TICK_STATUSES = {
	Running = true,
	Success = true,
	Fail = true,
}

local function _IsValidTickStatus(status: any): boolean
	return type(status) == "string" and VALID_TICK_STATUSES[status] == true
end

local function _BuildCombinedState(self: any, entity: number, config: any, services: any, dt: number): { [string]: any }
	local cursorKeys = if type(config.CursorKeys) == "table" then config.CursorKeys else {}
	local promiseKeys = if type(config.PromiseKeys) == "table" then config.PromiseKeys else {}
	local cursorDependencies = if type(config.CursorDependencies) == "table" then config.CursorDependencies else {}
	local state = {
		Entity = entity,
		DeltaTime = dt,
		Services = services,
		Cursors = {},
		Promises = {},
		PromiseStatuses = {},
		CursorDependencies = cursorDependencies,
		CursorCanAdvance = {},
	}

	-- Load the configured cursor slots.
	for _, key in ipairs(cursorKeys) do
		state.Cursors[key] = self:GetCursorSnapshot(entity, key)
	end

	-- Poll the configured Promise slots before building the aggregate status map.
	for _, key in ipairs(promiseKeys) do
		state.PromiseStatuses[key] = self:PollPromise(entity, key)
		state.Promises[key] = self:GetPromiseSnapshot(entity, key)
	end

	for _, key in ipairs(cursorKeys) do
		local dependencyKeys = cursorDependencies[key]
		if type(dependencyKeys) ~= "table" or #dependencyKeys == 0 then
			state.CursorCanAdvance[key] = true
		else
			state.CursorCanAdvance[key] = true
			for _, dependencyKey in ipairs(dependencyKeys) do
				if state.PromiseStatuses[dependencyKey] ~= "Resolved" then
					state.CursorCanAdvance[key] = false
					break
				end
			end
		end
	end

	return state
end

local function _ResolveTickHelperStatus(self: any, entity: number, status: any, reason: any): string?
	if not _IsValidTickStatus(status) then
		return nil
	end

	if status == "Fail" then
		return self:Fail(entity, if type(reason) == "string" then reason else nil)
	end

	return status
end

local function _ResolveCombinedFailureReason(self: any, entity: number, promiseKeys: { string }): string?
	for _, key in ipairs(promiseKeys) do
		if self:HasRejectedPromise(entity, key) then
			local promiseError = self:GetPromiseError(entity, key)
			if type(promiseError) == "string" then
				return promiseError
			end
			if type(promiseError) == "table" and type(promiseError.message) == "string" then
				return promiseError.message
			end
			return key
		end
	end

	return nil
end

local function _ApplyCursorAdvanceGate(self: any, entity: number, state: { [string]: any })
	self._cursorAdvanceGate[entity] = state.CursorCanAdvance
end

local function _ClearCursorAdvanceGate(self: any, entity: number)
	self._cursorAdvanceGate[entity] = nil
end

return function(BaseExecutor)
	function BaseExecutor:TickCursor(entity: number, key: string, callback: (cursor: any) -> any): any
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return nil
		end

		return callback(cursor)
	end

	function BaseExecutor:RunCursorChunk(entity: number, key: string, callback: (cursor: any) -> boolean): boolean
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return false
		end

		return callback(cursor)
	end

	function BaseExecutor:TransitionCursorPhase(entity: number, key: string, nextPhase: string, resetFields: any?)
		local cursor = self:GetCursor(entity, key)
		local cursorAdvanceGate = self._cursorAdvanceGate[entity]
		if cursor == nil or (cursorAdvanceGate ~= nil and cursorAdvanceGate[key] ~= true) then
			return
		end

		cursor.Phase = nextPhase
		cursor.IsDone = false

		if type(resetFields) ~= "table" then
			return
		end

		for fieldName, fieldValue in pairs(resetFields) do
			cursor[fieldName] = fieldValue
		end
	end

	function BaseExecutor:ArePromisesResolved(entity: number, keys: { string }): boolean
		for _, key in ipairs(keys) do
			if self:PollPromise(entity, key) ~= "Resolved" then
				return false
			end
		end

		return true
	end

	function BaseExecutor:HasPromiseRejected(entity: number, keys: { string }): boolean
		for _, key in ipairs(keys) do
			if self:PollPromise(entity, key) == "Rejected" then
				return true
			end
		end

		return false
	end

	function BaseExecutor:AreCursorsDone(entity: number, keys: { string }): boolean
		for _, key in ipairs(keys) do
			if not self:IsCursorDone(entity, key) then
				return false
			end
		end

		return true
	end

	function BaseExecutor:IsCombinedWorkDone(entity: number, config: any): boolean
		local cursorKeys = if type(config.CursorKeys) == "table" then config.CursorKeys else {}
		local promiseKeys = if type(config.PromiseKeys) == "table" then config.PromiseKeys else {}

		return self:AreCursorsDone(entity, cursorKeys) and self:ArePromisesResolved(entity, promiseKeys)
	end

	function BaseExecutor:IsWorkPending(entity: number, config: any): boolean
		return not self:IsCombinedWorkDone(entity, config)
	end

	function BaseExecutor:TickPartial(entity: number, key: string, dt: number, services: any, config: any): string
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return self:Fail(entity, "MissingCursor")
		end

		local status, reason
		if type(config) == "table" and type(config.Run) == "function" then
			status, reason = config.Run(cursor, services, dt)
		end

		local resolvedStatus = _ResolveTickHelperStatus(self, entity, status, reason)
		if resolvedStatus == "Fail" then
			if type(config) == "table" and type(config.OnFail) == "function" then
				config.OnFail(cursor, services, reason)
			end
			return resolvedStatus
		end

		if resolvedStatus == "Success" or cursor.IsDone == true then
			if type(config) == "table" and type(config.OnDone) == "function" then
				config.OnDone(cursor, services)
			end
			return self:Success()
		end

		return self:Running()
	end

	function BaseExecutor:TickPromise(entity: number, key: string, dt: number, services: any, config: any): string
		local status = self:PollPromise(entity, key)
		if status == "Missing" then
			if type(config) == "table" and config.AllowMissingPromise == true then
				return self:Running()
			end

			return self:Fail(entity, "MissingPromise")
		end

		if status == "Pending" or status == "Idle" then
			return self:Running()
		end

		if status == "Cancelled" then
			local cancelStatus = if type(config) == "table" then config.CancelStatus else nil
			local resolvedCancelStatus = _ResolveTickHelperStatus(self, entity, cancelStatus, nil)
			return if resolvedCancelStatus ~= nil then resolvedCancelStatus else self:Running()
		end

		if status == "Rejected" then
			local promiseError = self:ConsumePromiseError(entity, key, false)
			if type(config) == "table" and type(config.OnRejected) == "function" then
				config.OnRejected(promiseError, services, dt)
			end
			if type(config) == "table" and config.ClearOnRejected ~= false then
				self:ClearPromise(entity, key, false)
			end

			local rejectStatus = if type(config) == "table" then config.RejectStatus else nil
			local resolvedRejectStatus = _ResolveTickHelperStatus(
				self,
				entity,
				if rejectStatus ~= nil then rejectStatus else "Fail",
				promiseError
			)
			return if resolvedRejectStatus ~= nil then resolvedRejectStatus else self:Fail(entity, nil)
		end

		local result = self:ConsumePromiseResult(entity, key, false)
		local callbackStatus, callbackReason
		if type(config) == "table" and type(config.OnResolved) == "function" then
			callbackStatus, callbackReason = config.OnResolved(result, services, dt)
		end
		if type(config) == "table" and config.ClearOnResolved ~= false then
			self:ClearPromise(entity, key, false)
		end

		local resolvedStatus = _ResolveTickHelperStatus(self, entity, callbackStatus, callbackReason)
		if resolvedStatus ~= nil then
			return resolvedStatus
		end

		return if type(config) == "table" and type(config.ResolveStatus) == "string"
			then config.ResolveStatus
			else self:Success()
	end

	function BaseExecutor:TickCombined(entity: number, dt: number, services: any, config: any): string
		local cursorKeys = if type(config) == "table" and type(config.CursorKeys) == "table" then config.CursorKeys else {}
		local promiseKeys = if type(config) == "table" and type(config.PromiseKeys) == "table" then config.PromiseKeys else {}
		local cursorDependencies = if type(config) == "table" and type(config.CursorDependencies) == "table"
			then config.CursorDependencies
			else {}
		local state = _BuildCombinedState(self, entity, {
			CursorKeys = cursorKeys,
			PromiseKeys = promiseKeys,
			CursorDependencies = cursorDependencies,
		}, services, dt)

		if self:HasPromiseRejected(entity, promiseKeys) and (type(config) ~= "table" or config.FailOnRejectedPromises ~= false) then
			return self:Fail(entity, _ResolveCombinedFailureReason(self, entity, promiseKeys))
		end

		if type(config) == "table" and type(config.Poll) == "function" then
			local pollStatus, pollReason = config.Poll(state, services, dt)
			local resolvedPollStatus = _ResolveTickHelperStatus(self, entity, pollStatus, pollReason)
			if resolvedPollStatus ~= nil and resolvedPollStatus ~= "Running" then
				return resolvedPollStatus
			end
		end

		if type(config) == "table" and type(config.Advance) == "function" then
			_ApplyCursorAdvanceGate(self, entity, state)
			local ok, advanceStatus, advanceReason = xpcall(function()
				return config.Advance(state, services, dt)
			end, function(thrown)
				return thrown
			end)
			_ClearCursorAdvanceGate(self, entity)
			if not ok then
				error(advanceStatus, 0)
			end
			local resolvedAdvanceStatus = _ResolveTickHelperStatus(self, entity, advanceStatus, advanceReason)
			if resolvedAdvanceStatus ~= nil and resolvedAdvanceStatus ~= "Running" then
				return resolvedAdvanceStatus
			end
		end

		state = _BuildCombinedState(self, entity, {
			CursorKeys = cursorKeys,
			PromiseKeys = promiseKeys,
			CursorDependencies = cursorDependencies,
		}, services, dt)

		if type(config) == "table" and type(config.IsDone) == "function" then
			if config.IsDone(state) then
				return self:Success()
			end
			return self:Running()
		end

		if self:IsCombinedWorkDone(entity, {
			CursorKeys = cursorKeys,
			PromiseKeys = promiseKeys,
		}) then
			return self:Success()
		end

		return self:Running()
	end
end
