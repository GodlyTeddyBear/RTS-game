--!strict

return function(BaseExecutor)
	--[=[
		@within BaseExecutor
		Returns the running action status label.
		@return string -- The shared running status string.
	]=]
	function BaseExecutor:Running(): string
		return "Running"
	end

	--[=[
		@within BaseExecutor
		Returns the success action status label.
		@return string -- The shared success status string.
	]=]
	function BaseExecutor:Success(): string
		return "Success"
	end

	--[=[
		@within BaseExecutor
		Stores the failure reason for the entity and returns the fail status label.
		@param entity number -- Entity id associated with the failure.
		@param reason string? -- Optional failure reason to store for diagnostics.
		@return string -- The shared fail status string.
	]=]
	function BaseExecutor:Fail(entity: number, reason: string?): string
		if reason ~= nil then
			self._lastFailureReason[entity] = reason
		end

		return "Fail"
	end

	--[=[
		@within BaseExecutor
		Returns the last stored failure reason for the entity.
		@param entity number -- Entity id to inspect.
		@return string? -- Most recent failure reason, if present.
	]=]
	function BaseExecutor:GetLastFailureReason(entity: number): string?
		return self._lastFailureReason[entity]
	end
end
