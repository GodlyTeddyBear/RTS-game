--!strict

local function cleanupAsyncResource(resource: any, cleanup: ((resource: any) -> ()) | string?)
	if resource == nil then
		return
	end

	if type(cleanup) == "function" then
		cleanup(resource)
		return
	end

	if type(cleanup) == "string" then
		local cleanupMethod = resource[cleanup]
		if type(cleanupMethod) == "function" then
			cleanupMethod(resource)
		end
		return
	end

	local defaultCleanupMethods = {
		"cancel",
		"Cancel",
		"disconnect",
		"Disconnect",
		"destroy",
		"Destroy",
	}

	for _, methodName in ipairs(defaultCleanupMethods) do
		local cleanupMethod = resource[methodName]
		if type(cleanupMethod) == "function" then
			cleanupMethod(resource)
			return
		end
	end
end

return function(BaseExecutor)
	--[=[
		@within BaseExecutor
		Tracks an async resource for later cleanup and replaces any previous resource with the same key.
		@param entity number -- Entity id that owns the resource.
		@param key string -- Stable resource key for this executor.
		@param resource any -- Async resource to track.
		@param cleanup ((resource: any) -> ()) | string? -- Optional cleanup function or method name.
	]=]
	function BaseExecutor:TrackAsyncResource(entity: number, key: string, resource: any, cleanup: ((resource: any) -> ()) | string?)
		local trackedResources = self._trackedAsyncResources[entity]
		if trackedResources == nil then
			trackedResources = {}
			self._trackedAsyncResources[entity] = trackedResources
		end

		local previous = trackedResources[key]
		if previous ~= nil then
			cleanupAsyncResource(previous.Resource, previous.Cleanup)
		end

		trackedResources[key] = {
			Resource = resource,
			Cleanup = cleanup,
		}
	end

	--[=[
		@within BaseExecutor
		Returns a tracked async resource for one entity.
		@param entity number -- Entity id being processed.
		@param key string -- Resource key to inspect.
		@return any -- Tracked async resource, if present.
	]=]
	function BaseExecutor:GetAsyncResource(entity: number, key: string): any
		local trackedResources = self._trackedAsyncResources[entity]
		if trackedResources == nil then
			return nil
		end

		local trackedResource = trackedResources[key]
		if trackedResource == nil then
			return nil
		end

		return trackedResource.Resource
	end

	--[=[
		@within BaseExecutor
		Releases one tracked async resource for an entity and optionally runs its cleanup path.
		@param entity number -- Entity id being processed.
		@param key string -- Resource key to release.
		@param shouldCleanup boolean? -- Whether to execute the cleanup path before clearing the resource.
	]=]
	function BaseExecutor:ReleaseAsyncResource(entity: number, key: string, shouldCleanup: boolean?)
		local trackedResources = self._trackedAsyncResources[entity]
		if trackedResources == nil then
			return
		end

		local trackedResource = trackedResources[key]
		if trackedResource == nil then
			return
		end

		if shouldCleanup ~= false then
			cleanupAsyncResource(trackedResource.Resource, trackedResource.Cleanup)
		end

		trackedResources[key] = nil
		if next(trackedResources) == nil then
			self._trackedAsyncResources[entity] = nil
		end
	end

	--[=[
		@within BaseExecutor
		Cleans up all tracked async resources for an entity.
		@param entity number -- Entity id being processed.
	]=]
	function BaseExecutor:CleanupAsyncResources(entity: number)
		local trackedResources = self._trackedAsyncResources[entity]
		if trackedResources == nil then
			return
		end

		for key, trackedResource in pairs(trackedResources) do
			cleanupAsyncResource(trackedResource.Resource, trackedResource.Cleanup)
			trackedResources[key] = nil
		end

		self._trackedAsyncResources[entity] = nil
	end

	--[=[
		@within BaseExecutor
		Tracks a Promise-like task for later cancellation or cleanup.
		@param entity number -- Entity id that owns the task.
		@param key string -- Stable task key for this executor.
		@param taskLike any -- Promise-like object to track.
	]=]
	function BaseExecutor:TrackTask(entity: number, key: string, taskLike: any)
		self:TrackAsyncResource(entity, key, taskLike, "cancel")
	end

	--[=[
		@within BaseExecutor
		Returns a tracked Promise-like task for one entity.
		@param entity number -- Entity id being processed.
		@param key string -- Task key to inspect.
		@return any -- Tracked task-like object, if present.
	]=]
	function BaseExecutor:GetTrackedTask(entity: number, key: string): any
		return self:GetAsyncResource(entity, key)
	end

	--[=[
		@within BaseExecutor
		Clears one tracked Promise-like task for an entity without cancelling it.
		@param entity number -- Entity id being processed.
		@param key string -- Task key to clear.
	]=]
	function BaseExecutor:ClearTrackedTask(entity: number, key: string)
		self:ReleaseAsyncResource(entity, key, false)
	end

	--[=[
		@within BaseExecutor
		Cancels all tracked Promise-like tasks for an entity.
		@param entity number -- Entity id being processed.
	]=]
	function BaseExecutor:CancelTrackedTasks(entity: number)
		self:CleanupAsyncResources(entity)
	end
end
